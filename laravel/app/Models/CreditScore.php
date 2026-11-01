<?php

namespace App\Models;

use App\Casts\EncryptedDecimal;
use Illuminate\Database\Eloquent\Model;

class CreditScore extends Model
{
    protected $fillable = [
        'user_id',
        'statement_id',
        'default_probability',
        'score',
        'risk_tier',
        'high_risk',
        'top_drivers',
        'features',
        'imputed_features',
        'out_of_range_features',
        'model_version',
        'scored_at'
    ];

    // The score, the default probability and the behavioural detail (features and drivers) are encrypted
    // at rest with the application key. The tier, the high-risk flag and the dates stay readable.
    protected $casts = [
        'default_probability' => EncryptedDecimal::class . ':5',
        'score' => EncryptedDecimal::class . ':2',
        'top_drivers' => 'encrypted:array',
        'features' => 'encrypted:array',
        'imputed_features' => 'encrypted:array',
        'out_of_range_features' => 'encrypted:array',
        'high_risk' => 'boolean',
        'scored_at' => 'datetime',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function statement()
    {
        return $this->belongsTo(Statement::class);
    }
}
