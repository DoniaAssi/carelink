<?php

/**
 * IDE-only stubs when `vendor/` is missing. After you run `composer install` in this
 * folder, delete this file to avoid duplicate-class hints in the editor.
 */
declare(strict_types=1);

namespace Illuminate\Database\Migrations {

    abstract class Migration
    {
        abstract public function up(): void;

        abstract public function down(): void;
    }
}

namespace Illuminate\Support\Facades {

    use Closure;
    use Illuminate\Database\Schema\Blueprint;

    class Schema
    {
        public static function create(string $table, Closure $callback): void {}

        public static function table(string $table, Closure $callback): void {}

        public static function dropIfExists(string $table): void {}

        public static function hasColumn(string $table, string $column): bool
        {
            return false;
        }
    }
}

namespace Illuminate\Database\Schema {

    class Blueprint
    {
        /** @return $this */
        public function id(): self
        {
            return $this;
        }

        /**
         * @return $this
         */
        public function string(string $column, int $length = 255): self
        {
            return $this;
        }

        /** @return $this */
        public function boolean(string $column): self
        {
            return $this;
        }

        /** @return $this */
        public function timestampTz(string $column, int $precision = 0): self
        {
            return $this;
        }

        /**
         * @param  array<int, string>|string  $columns
         * @return $this
         */
        public function index(array|string $columns): self
        {
            return $this;
        }

        /** @return $this */
        public function after(string $column): self
        {
            return $this;
        }

        /** @param  mixed  $value */
        public function default(mixed $value): self
        {
            return $this;
        }

        /** @return $this */
        public function nullable(): self
        {
            return $this;
        }

        /** @return $this */
        public function useCurrent(): self
        {
            return $this;
        }
    }
}
