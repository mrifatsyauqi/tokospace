<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Default Filesystem Disk
    |--------------------------------------------------------------------------
    |
    | Here you may specify the default filesystem disk that should be used
    | by the framework. The "local" disk, as well as a variety of cloud
    | based disks are available to your application for file storage.
    |
    */

    /*
    | Tech Spec §1.1: 'local' is for transient data only (temp uploads, framework
    | cache/log) — it is never the source of truth for production media. 'gcs'
    | is the default disk (ADR-0001 target: Google Cloud Storage) so every
    | upload feature writes there unless a Temp/ path explicitly opts into
    | 'local'. 'r2' (Cloudflare, current pre-migration disk) stays defined
    | below until the storage cutover in ADR-0001 is executed — see
    | docs/adr/0001-gcp-cloud-sql-hosting-migration.md.
    */
    'default' => env('FILESYSTEM_DISK', 'gcs'),

    /*
    |--------------------------------------------------------------------------
    | Filesystem Disks
    |--------------------------------------------------------------------------
    |
    | Below you may configure as many filesystem disks as necessary, and you
    | may even configure multiple disks for the same driver. Examples for
    | most supported storage drivers are configured here for reference.
    |
    | Supported drivers: "local", "ftp", "sftp", "s3"
    |
    */

    'disks' => [

        // Transient only: temp upload processing, framework cache/log. Never
        // production media — see app/Modules/*/Temp/ convention (Tech Spec §1.1).
        'local' => [
            'driver' => 'local',
            'root' => storage_path('app/private'),
            'serve' => true,
            'throw' => false,
            'report' => false,
        ],

        'public' => [
            'driver' => 'local',
            'root' => storage_path('app/public'),
            'url' => env('APP_URL').'/storage',
            'visibility' => 'public',
            'throw' => false,
            'report' => false,
        ],

        // Google Cloud Storage — ADR-0001 target disk for all production
        // media: product photos, logos, banners, proof-of-transfer,
        // invoices, import/export. Driver registered in
        // App\Providers\AppServiceProvider::boot() (Laravel core doesn't
        // recognize 'gcs' natively the way it does 's3'). 'key_file' stays
        // unset in production — the GCE service account attached to the VM
        // is used via Application Default Credentials instead.
        'gcs' => [
            'driver' => 'gcs',
            'project_id' => env('GCS_PROJECT_ID'),
            'key_file' => env('GCS_KEY_FILE'),
            'bucket' => env('GCS_BUCKET'),
            'path_prefix' => env('GCS_PATH_PREFIX', ''),
            'throw' => false,
            'report' => false,
        ],

        // Cloudflare R2 (S3-compatible) — current pre-migration production
        // disk, kept defined until the ADR-0001 storage cutover to 'gcs' is
        // executed. Do not add new code that writes here.
        'r2' => [
            'driver' => 's3',
            'key' => env('R2_ACCESS_KEY_ID'),
            'secret' => env('R2_SECRET_ACCESS_KEY'),
            'region' => env('R2_DEFAULT_REGION', 'auto'),
            'bucket' => env('R2_BUCKET'),
            'url' => env('R2_URL'),
            'endpoint' => env('R2_ENDPOINT'),
            'use_path_style_endpoint' => env('R2_USE_PATH_STYLE_ENDPOINT', true),
            'throw' => false,
            'report' => false,
        ],

    ],

    /*
    |--------------------------------------------------------------------------
    | Symbolic Links
    |--------------------------------------------------------------------------
    |
    | Here you may configure the symbolic links that will be created when the
    | `storage:link` Artisan command is executed. The array keys should be
    | the locations of the links and the values should be their targets.
    |
    */

    'links' => [
        public_path('storage') => storage_path('app/public'),
    ],

];
