<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class LoanRequest extends Model
{
    // Input sanity limits (they catch typing mistakes). They are not lending policy.
    public const MIN_AMOUNT = 1000;
    public const MAX_AMOUNT = 5000000;
    public const MIN_TERM_MONTHS = 1;
    public const MAX_TERM_MONTHS = 60;

    protected $fillable = ['user_id', 'lender_id', 'score_access_grant_id', 'amount', 'term_months',
        'purpose', 'status', 'decision_note', 'responded_at'];

    protected $casts = ['amount' => 'decimal:2', 'responded_at' => 'datetime'];

    public function borrower() { return $this->belongsTo(User::class, 'user_id'); }
    public function lender() { return $this->belongsTo(Lender::class); }
    public function grant() { return $this->belongsTo(ScoreAccessGrant::class, 'score_access_grant_id'); }
}
