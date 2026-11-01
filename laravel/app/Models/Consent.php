<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Consent extends Model
{
    public const STATEMENT_ANALYSIS = 'statement_analysis';
    public const PURPOSES = [self::STATEMENT_ANALYSIS];
    public const CURRENT_POLICY_VERSION = '1.0';

    protected $fillable = ['user_id', 'purpose', 'policy_version', 'granted_at', 'revoked_at'];
    protected $casts = ['granted_at' => 'datetime', 'revoked_at' => 'datetime'];

    public function user() { return $this->belongsTo(User::class); }
    public function scopeActive($q) { return $q->whereNull('revoked_at'); }
}
