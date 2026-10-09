<?php

namespace App\Models;

// use Illuminate\Contracts\Auth\MustVerifyEmail;
use Laravel\Sanctum\HasApiTokens; 
use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Illuminate\Support\Facades\Crypt;


class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasApiTokens, HasFactory, Notifiable;

    protected $fillable = [
        'name',
        'email',
        'phone_number',
        'national_id',
        'national_id_hash',
        'password'
    ];

    protected $hidden = [
        'password',
        'remember_token',
        'national_id',
        'national_id_hash',
    ];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
            'identity_verified_at' => 'datetime',
        ];
    }
    
    /**
     * Encrypt national ID before storing it.
     */
    public function setNationalIdAttribute(?string $value): void
    {
        if ($value === null || trim($value) === '') {
            $this->attributes['national_id'] = null;
            $this->attributes['national_id_hash'] = null;
            return;
        }

        $normalized = trim($value);

        $this->attributes['national_id'] = Crypt::encryptString($normalized);
        $this->attributes['national_id_hash'] = hash('sha256', $normalized);
    }

     /**
     * Decrypt national ID when accessing it.
     */
    public function getNationalIdAttribute(?string $value): ?string
    {
        if ($value === null) {
            return null;
        }

        return Crypt::decryptString($value);
    }
}
