<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

// Tech Spec §14 — withoutOverlapping in case a previous run is still
// uploading when the next one fires; onFailure logs loudly since a silently
// skipped backup is exactly the failure mode this exists to prevent.
Schedule::command('app:backup-database')
    ->dailyAt('02:00')
    ->withoutOverlapping()
    ->onFailure(fn () => Log::critical('Scheduled database backup failed — check app:backup-database output.'));
