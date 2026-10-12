<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class AdminSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $user = User::firstOrNew([
            'email' => env('ADMIN_EMAIL'),
        ]);

        $user->forceFill([
            'name' => 'MtaaWorks Admin',
            'password' => Hash::make(env('ADMIN_PASSWORD')),
            'role' => User::ROLE_ADMIN,
            'email_verified_at' => now(),
        ])->save();
    }
}
