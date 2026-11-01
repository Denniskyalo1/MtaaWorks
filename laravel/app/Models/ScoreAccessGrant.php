<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ScoreAccessGrant extends Model
{
    public const SCOPES = ['score_tier', 'score_tier_drivers'];
    public const VALIDITY_DAYS = 30;

    protected $fillable = ['lender_id', 'user_id', 'requested_by', 'credit_score_id', 'scope',
        'status', 'requested_at', 'responded_at', 'expires_at', 'revoked_at'];
    protected $casts = ['requested_at' => 'datetime', 'responded_at' => 'datetime',
        'expires_at' => 'datetime', 'revoked_at' => 'datetime', 'last_viewed_at' => 'datetime'];

    public function lender() { return $this->belongsTo(Lender::class); }
    public function borrower() { return $this->belongsTo(User::class, 'user_id'); }
    public function creditScore() { return $this->belongsTo(CreditScore::class); }

    public function isUsable(): bool
    {
        return $this->status === 'approved' && $this->expires_at && $this->expires_at->isFuture();
    }

    public static function expireDue(): void
    {
        static::where('status', 'approved')->where('expires_at', '<=', now())->update(['status' => 'expired']);
    }
}
