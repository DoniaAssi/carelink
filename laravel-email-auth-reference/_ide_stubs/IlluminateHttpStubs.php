<?php

namespace Illuminate\Http;

class Request
{
    /** @param  array<string, mixed>  $rules */
    public function validate(array $rules): array
    {
        return [];
    }
}

class JsonResponse extends Response
{
    /** @param  array<string, mixed>  $data */
    public function __construct(mixed $data = [], int $status = 200)
    {
    }
}

class Response
{
}
