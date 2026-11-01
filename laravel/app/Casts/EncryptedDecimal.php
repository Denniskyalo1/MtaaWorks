<?php

namespace App\Casts;

use Illuminate\Contracts\Database\Eloquent\CastsAttributes;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Crypt;

/**
 * Stores a decimal number encrypted with the application key and returns it as a string with a fixed
 * number of decimal places, the same format a DECIMAL column returned before. Usage: EncryptedDecimal::class . ':2'
 */
class EncryptedDecimal implements CastsAttributes
{
    public function __construct(private int $scale = 2)
    {
    }

    public function get(Model $model, string $key, mixed $value, array $attributes): ?string
    {
        if ($value === null) {
            return null;
        }

        return number_format((float) Crypt::decryptString($value), $this->scale, '.', '');
    }

    public function set(Model $model, string $key, mixed $value, array $attributes): ?string
    {
        return $value === null ? null : Crypt::encryptString((string) $value);
    }
}
