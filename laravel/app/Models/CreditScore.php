<?php

namespace App\Models;

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


    protected $casts = [
    'top_drivers' => 'array',
    'features' => 'array',
    'imputed_features' => 'array',
    'out_of_range_features' => 'array','high_risk' => 'boolean','scored_at' => 'datetime'
    ];

    
public function user() { 
    return $this->belongsTo(User::class); 
    
}


public function statement() {
     return $this->belongsTo(Statement::class);
 }
}
