<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ScoreAccessEvent extends Model
{
    public const UPDATED_AT = null;

    protected $fillable = ['score_access_grant_id', 'lender_id', 'viewer_user_id', 'event', 'scope'];

    protected $casts = ['created_at' => 'datetime'];

    public function grant() { return $this->belongsTo(ScoreAccessGrant::class, 'score_access_grant_id'); }
    public function lender() { return $this->belongsTo(Lender::class); }

    /** Record that a lender user opened the score shared by this grant. */
    public static function record(ScoreAccessGrant $grant, ?User $viewer, string $event = 'viewed'): self
    {
        return static::create([
            'score_access_grant_id' => $grant->id,
            'lender_id' => $grant->lender_id,
            'viewer_user_id' => $viewer?->id,
            'event' => $event,
            'scope' => $grant->scope,
        ]);
    }
}
