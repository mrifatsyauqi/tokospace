<?php

use App\Http\Controllers\HealthController;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

// Root-level, not /api/health — this whole app IS api.tokospace.com (Tech Spec §3).
Route::get('/health', HealthController::class);
