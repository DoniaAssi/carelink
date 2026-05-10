<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * Reference model. In a full Laravel app, use Authenticatable or merge into your User.
 *
 * @property int|string|null $id
 * @property string $name
 * @property string $email
 * @property string $password
 * @property bool $is_verified
 */
class User extends Model
{
    protected $fillable = [
        'name',
        'email',
        'password',
        'is_verified',
    ];

    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected $casts = [
        'email_verified_at' => 'datetime',
        'is_verified' => 'boolean',
    ];
}
