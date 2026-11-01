<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Statement extends Model
{
    protected $fillable = [
        'user_id',
        'period_start',
        'period_end',
        'validation'
    ];

    protected $casts = [
        'period_start' => 'date',
        'period_end' => 'date',
        'validation' => 'array'
    ];
    
    public function user() {
         return $this->belongsTo(User::class);
    }

    public function creditScore() {
         return $this->hasOne(CreditScore::class); 
    }
}
