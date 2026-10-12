<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ProfileUpdateTest extends TestCase
{
    use RefreshDatabase;

    public function test_profile_update_ignores_protected_fields(): void
    {
        $user = User::factory()->create(['identity_verification_status' => 'unverified']);
        $beforeHash = $user->national_id_hash;
        Sanctum::actingAs($user);

        $this->patchJson('/api/update', [
            'name' => 'New Name',
            'national_id' => '99999999',
            'identity_verification_status' => 'verified',
        ])->assertOk();

        $user->refresh();
        $this->assertSame('New Name', $user->name);
        $this->assertSame('unverified', $user->identity_verification_status);
        $this->assertSame($beforeHash, $user->national_id_hash);
    }
}