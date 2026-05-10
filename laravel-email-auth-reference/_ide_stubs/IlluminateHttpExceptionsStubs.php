<?php

declare(strict_types=1);

namespace Illuminate\Http\Exceptions;

use Throwable;

class HttpResponseException extends \RuntimeException
{
    /**
     * @param  mixed  $response
     */
    public function __construct(mixed $response = null, int $code = 0, ?Throwable $previous = null)
    {
        parent::__construct('', $code, $previous);
    }
}
