<?php

/**
 * Copy into your Laravel app as `config/cors.php`.
 * Dev-only: allows any origin (Flutter Web on random localhost ports).
 *
 * After editing:
 *   php artisan config:clear
 *   php artisan cache:clear
 *
 * Laravel 11: ensure `HandleCors` is enabled (default in `bootstrap/app.php`).
 *
 * Note: `allowed_origins` => ['*'] with `supports_credentials` => true is invalid
 * per spec; keep credentials false unless you list explicit origins.
 */

return [

    'paths' => ['api/*', 'sanctum/csrf-cookie'],

    'allowed_methods' => ['*'],

    'allowed_origins' => ['*'],

    'allowed_origins_patterns' => [],

    'allowed_headers' => ['*'],

    'exposed_headers' => [],

    'max_age' => 0,

    'supports_credentials' => false,

];
