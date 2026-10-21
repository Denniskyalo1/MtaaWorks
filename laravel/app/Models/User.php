<?php

namespace App\Models;

use Laravel\Sanctum\HasApiTokens; 
use Illuminate\Contracts\Auth\MustVerifyEmail;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Illuminate\Support\Facades\Crypt;


class User extends Authenticatable implements MustVerifyEmail
{


    /** @use HasFactory<UserFactory> */
    use HasApiTokens, HasFactory, Notifiable;


    public const ROLE_BORROWER = 'borrower';
    public const ROLE_LENDER   = 'lender';
    public const ROLE_ADMIN    = 'admin';

    protected $fillable = [
        'name',
        'email',
        'phone_number',

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
            'phone_verified_at' => 'datetime',
        ];
    }

    protected static function booted(): void{
    static::updating(function (User $user) {
        if ($user->isDirty('phone_number')) {
            $user->phone_verified_at = null;
        }
        if($user->isDirty('email')){
            $user->email_verified_at = null;
        }
    });
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
        $this->attributes['national_id_hash'] = hash_hmac('sha256', $normalized, config('app.key'));
    }

     /**
     * Decrypt national ID when accessing it.
     */
    /**
 * Decrypt national ID when accessing it.
 */
public function getNationalIdAttribute(?string $value): ?string
{
    if ($value === null || trim($value) === '') {
        return null;
    }

    return Crypt::decryptString($value);
}
    public function consents() { 
        return $this->hasMany(Consent::class);
     }

     public function statements() { 
        return $this->hasMany(Statement::class);
     }

     public function creditScores() { 
        return $this->hasMany(CreditScore::class);
     }

    /**
     * Get the lender that owns the user.
     */
    public function lender() {
         return $this->belongsTo(Lender::class); 
    }
}
