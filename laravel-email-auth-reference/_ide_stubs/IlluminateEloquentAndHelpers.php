<?php

declare(strict_types=1);

namespace Illuminate\Database\Eloquent {

    class Model
    {
        /** @var array<int, string> */
        protected $fillable = [];

        /** @var array<int, string> */
        protected $hidden = [];

        /** @var array<string, string> */
        protected $casts = [];

        public static function query(): Builder
        {
            return new Builder();
        }

        /** @return static */
        public static function where(mixed $column, mixed $operator = null, mixed $value = null): Builder
        {
            return new Builder();
        }

        /** @param  array<string, mixed>  $attributes */
        public static function create(array $attributes): static
        {
            return new static();
        }

        public function save(array $options = []): bool
        {
            return true;
        }

        public function getKey(): int|string|null
        {
            return null;
        }
    }

    class Builder
    {
        /** @return $this */
        public function where(mixed $column, mixed $operator = null, mixed $value = null): self
        {
            return $this;
        }

        /** @return $this */
        public function whereNull(string $column): self
        {
            return $this;
        }

        /** @return $this */
        public function orderByDesc(string $column): self
        {
            return $this;
        }

        /** @return $this */
        public function limit(int $n): self
        {
            return $this;
        }

        public function exists(): bool
        {
            return false;
        }

        /** @return \Illuminate\Support\Collection<int, object> */
        public function get(): \Illuminate\Support\Collection
        {
            return new \Illuminate\Support\Collection([]);
        }

        public function first(): ?object
        {
            return null;
        }

        /** @return object */
        public function firstOrFail(): object
        {
            $row = $this->first();
            if ($row === null) {
                throw new \RuntimeException('Model not found');
            }

            return $row;
        }
    }
}

namespace Illuminate\Support {

    /**
     * @template TKey of array-key
     * @template TValue
     */
    class Collection
    {
        /** @param  array<TKey, TValue>  $items */
        public function __construct(
            /** @var array<TKey, TValue> */
            protected array $items = [],
        ) {
        }
    }
}

namespace Illuminate\Routing {

    class ResponseFactory
    {
        /**
         * @param  array<string, mixed>  $data
         */
        public function json(mixed $data = [], int $status = 200, array $headers = [], int $options = 0): \Illuminate\Http\JsonResponse
        {
            return new \Illuminate\Http\JsonResponse();
        }
    }
}

namespace {

    function response(mixed $content = null): \Illuminate\Routing\ResponseFactory
    {
        return new \Illuminate\Routing\ResponseFactory();
    }

    /**
     * @param  string|null  $abstract
     */
    function app(?string $abstract = null): mixed
    {
        if ($abstract !== null) {
            return null;
        }

        return new class {
            /** @param  mixed  $patterns */
            public function environment(mixed ...$patterns): bool|string
            {
                return false;
            }
        };
    }
}
