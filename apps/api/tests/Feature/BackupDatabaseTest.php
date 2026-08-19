<?php

use Illuminate\Support\Facades\Storage;

test('backup uploads a compressed dump to gcs and prunes old backups', function () {
    if (config('database.default') !== 'pgsql') {
        $this->markTestSkipped('app:backup-database requires the pgsql driver (pg_dump).');
    }

    Storage::fake('gcs');

    // Pre-existing backup older than the 30-day retention window (Tech Spec §14).
    Storage::disk('gcs')->put('backups/database/old.sql.gz', 'stale');
    touch(Storage::disk('gcs')->path('backups/database/old.sql.gz'), now()->subDays(31)->timestamp);

    $this->artisan('app:backup-database')->assertSuccessful();

    $files = Storage::disk('gcs')->files('backups/database');

    expect($files)->toHaveCount(1)
        ->and($files[0])->not->toBe('backups/database/old.sql.gz')
        ->and($files[0])->toEndWith('.sql.gz');
});

test('backup fails loudly when the upload to gcs fails', function () {
    if (config('database.default') !== 'pgsql') {
        $this->markTestSkipped('app:backup-database requires the pgsql driver (pg_dump).');
    }

    // No fake disk configured — the real 'gcs' disk has no credentials or
    // network access to a real bucket in testing, so the upload must fail
    // and the command must NOT report success (this is a regression test
    // for a real bug found during Stage 0 verification: 'throw' => false
    // made put() fail silently).
    $this->artisan('app:backup-database')->assertFailed();
});
