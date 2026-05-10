These PHP files exist only so editors (e.g. VS Code Intelephense) resolve Laravel types
when `vendor/` is not installed yet.

After you run `composer install` in `laravel-email-auth-reference/`, delete this entire
`_ide_stubs` folder to avoid duplicate-class diagnostics.

Alternatively, keep `_ide_stubs` and do not run Composer here if you only copy snippets
into a full Laravel app.
