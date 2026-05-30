<?php

declare(strict_types=1);

namespace Illuminate\Support\Facades;

class Hash
{
    public static function make(string $value): string
    {
        return '';
    }

    public static function check(string $value, string $hashedValue): bool
    {
        return false;
    }
}

class Log
{
    /** @param  array<string, mixed>  $context */
    public static function error(string $message, array $context = []): void {}
}

class Mail
{
    public static function to(mixed $users): \Illuminate\Mail\PendingMail
    {
        return new \Illuminate\Mail\PendingMail();
    }
}
