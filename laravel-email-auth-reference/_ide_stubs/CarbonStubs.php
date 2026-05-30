<?php

declare(strict_types=1);

namespace Carbon;

class Carbon
{
    public static function now(): self
    {
        return new self();
    }

    public function getTimestamp(): int
    {
        return 0;
    }

    /** @return $this */
    public function addMinutes(int $minutes): self
    {
        return $this;
    }
}
