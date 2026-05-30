<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('users') && ! Schema::hasColumn('users', 'is_verified')) {
            Schema::table('users', function (Blueprint $table) {
                $table->boolean('is_verified')->default(false);
            });
        }

        if (! Schema::hasTable('email_verification_codes')) {
            Schema::create('email_verification_codes', function (Blueprint $table) {
                $table->id();
                $table->string('email', 320)->index();
                $table->string('otp_hash', 255);
                $table->timestampTz('expires_at');
                $table->timestampTz('used_at')->nullable();
                $table->timestampTz('created_at')->useCurrent();
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('email_verification_codes');

        if (Schema::hasTable('users') && Schema::hasColumn('users', 'is_verified')) {
            Schema::table('users', function (Blueprint $table) {
                $table->dropColumn('is_verified');
            });
        }
    }
};
