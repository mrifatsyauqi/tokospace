<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\Storage;
use RuntimeException;
use Symfony\Component\Process\Process;
use Throwable;

/**
 * Tech Spec §14: daily compressed pg_dump, uploaded to R2 (never the Oracle
 * disk it ran on — a lost/rebuilt instance must not mean a lost backup),
 * 30-day retention enforced here rather than relying on R2 lifecycle rules
 * so the policy is visible in application code.
 */
class BackupDatabase extends Command
{
    protected $signature = 'app:backup-database';

    protected $description = 'Dump the database, compress it, and upload it to R2 with 30-day retention';

    private const RETENTION_DAYS = 30;

    private const BACKUP_PATH = 'backups/database';

    public function handle(): int
    {
        $connection = config('database.connections.'.config('database.default'));

        if (($connection['driver'] ?? null) !== 'pgsql') {
            $this->error('app:backup-database only supports the pgsql driver.');

            return self::FAILURE;
        }

        try {
            $this->dumpAndUpload($connection);
        } catch (Throwable $e) {
            $this->error($e->getMessage());

            return self::FAILURE;
        }

        return self::SUCCESS;
    }

    /**
     * @param  array<string, mixed>  $connection
     */
    private function dumpAndUpload(array $connection): void
    {
        $timestamp = now()->format('Y-m-d_His');
        $filename = "{$timestamp}.sql.gz";
        $sqlPath = storage_path("app/private/{$timestamp}.sql");
        $localPath = $sqlPath.'.gz';

        $this->info("Dumping database to {$filename}...");

        // pg_dump and gzip run as two separate, independently-checked
        // processes rather than a shell pipe: `pg_dump | gzip > file` would
        // report the exit status of gzip (the last command in the pipe), so
        // a failed/truncated pg_dump — bad host, dropped connection mid-dump
        // — could still produce and upload a "successful" empty backup.
        $dump = Process::fromShellCommandline(
            sprintf(
                'PGPASSWORD=%s pg_dump --host=%s --port=%s --username=%s --no-password --format=plain %s > %s',
                escapeshellarg($connection['password']),
                escapeshellarg($connection['host']),
                escapeshellarg((string) $connection['port']),
                escapeshellarg($connection['username']),
                escapeshellarg($connection['database']),
                escapeshellarg($sqlPath),
            )
        );
        $dump->setTimeout(600);
        $dump->run();

        if (! $dump->isSuccessful()) {
            @unlink($sqlPath);

            throw new RuntimeException('pg_dump failed: '.$dump->getErrorOutput());
        }

        $gzip = new Process(['gzip', '--force', $sqlPath]);
        $gzip->setTimeout(600);
        $gzip->run();

        if (! $gzip->isSuccessful()) {
            @unlink($sqlPath);

            throw new RuntimeException('gzip failed: '.$gzip->getErrorOutput());
        }

        $this->info('Uploading to R2...');

        $remotePath = self::BACKUP_PATH.'/'.$filename;

        // The r2 disk has 'throw' => false (Tech Spec §1.1 default for app
        // upload features, which prefer a handled false return over a
        // thrown exception) — put() failing silently would mean this command
        // reports success on a backup that was never actually written.
        $uploaded = Storage::disk('r2')->put($remotePath, fopen($localPath, 'r'));
        unlink($localPath);

        if (! $uploaded) {
            throw new RuntimeException("Upload to r2://{$remotePath} failed.");
        }

        $this->info("Uploaded to r2://{$remotePath}");

        $this->pruneOldBackups();
    }

    private function pruneOldBackups(): void
    {
        $cutoff = now()->subDays(self::RETENTION_DAYS);
        $deleted = 0;

        foreach (Storage::disk('r2')->files(self::BACKUP_PATH) as $path) {
            $timestamp = Storage::disk('r2')->lastModified($path);

            if ($timestamp !== false && $timestamp < $cutoff->timestamp) {
                Storage::disk('r2')->delete($path);
                $deleted++;
            }
        }

        if ($deleted > 0) {
            $this->info("Pruned {$deleted} backup(s) older than ".self::RETENTION_DAYS.' days.');
        }
    }
}
