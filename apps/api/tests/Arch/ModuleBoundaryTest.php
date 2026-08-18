<?php

/*
 * Placeholder for Tech Spec §10 module boundary rule: modules under
 * app/Modules/* must only reach each other through Services/, never by
 * importing another module's Models/ or Providers/ directly. app/Modules
 * has no real modules yet (Stage 0 is infrastructure only, Tahap 1+ adds
 * Tenant/Auth/Catalog/...), so the concrete per-module assertion is added
 * once there is more than one module to check boundaries between — see
 * Tech Spec §10 for the exact rule this will enforce.
 *
 * These two rules are real and enforced now, on the codebase as it exists
 * today, tagged so `pest --group=arch` runs them in CI (Tech Spec §9.1 /
 * NON-NEGOTIABLE rule #11 — tests must actually run, not just compile).
 */

arch('no debug statements left in application code')
    ->expect('App')
    ->not->toUse(['dd', 'dump', 'var_dump', 'die', 'exit', 'ray'])
    ->group('arch');

arch('controllers do not extend Eloquent models')
    ->expect('App\Http\Controllers')
    ->not->toExtend('Illuminate\Database\Eloquent\Model')
    ->group('arch');
