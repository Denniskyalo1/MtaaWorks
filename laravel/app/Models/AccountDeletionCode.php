<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class AccountDeletionCode extends Model
{
protected $fillable = [
    'user_id',
    'code_hash',
    'attempts',
    'expires_at'
];


protected $hidden   =[
    'code_hash'
];


protected $casts    = [
    'expires_at' => 'datetime'
];


}
