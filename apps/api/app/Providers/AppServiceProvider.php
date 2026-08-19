<?php

namespace App\Providers;

use Google\Cloud\Storage\StorageClient;
use Illuminate\Filesystem\FilesystemAdapter;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\ServiceProvider;
use League\Flysystem\Filesystem;
use League\Flysystem\GoogleCloudStorage\GoogleCloudStorageAdapter;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        // Laravel core recognizes 'local'/'s3' natively but not 'gcs' — this
        // wires league/flysystem-google-cloud-storage into the disk named
        // 'gcs' in config/filesystems.php (Tech Spec §1.1, ADR-0001 target
        // object storage).
        Storage::extend('gcs', function ($app, array $config) {
            $storageClient = new StorageClient(array_filter([
                'projectId' => $config['project_id'] ?? null,
                // Left unset in production: the GCE service account attached
                // to the VM is used via Application Default Credentials
                // instead of a committed key file (ADR-0001 §Secrets).
                'keyFilePath' => $config['key_file'] ?? null,
            ]));

            $adapter = new GoogleCloudStorageAdapter(
                $storageClient->bucket($config['bucket']),
                $config['path_prefix'] ?? '',
            );

            return new FilesystemAdapter(
                new Filesystem($adapter, $config),
                $adapter,
                $config,
            );
        });
    }
}
