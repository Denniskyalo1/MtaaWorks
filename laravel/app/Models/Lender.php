<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Lender extends Model
{
    public const TYPES = [
        'sacco',
        'mfi',
        'digital_lender'
    ];

    public const STATUS_ACTIVE = 'active';
    public const STATUS_SUSPENDED = 'suspended';

    protected $fillable = [
        'name',
        'type',
        'licence_number',
        'status',
        'created_by'
    ];

    public function staff() {
         return $this->hasMany(User::class);
     }

    public function isActive(): bool
    {
        return $this->status === self::STATUS_ACTIVE;
    }
}
