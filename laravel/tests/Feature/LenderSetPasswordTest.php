<?php

namespace Tests\Feature;

use App\Models\Lender;
use App\Models\User;
use Illuminate\Auth\Notifications\ResetPassword;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Notification;
use Illuminate\Support\Facades\Password;
use Tests\TestCase;

class LenderSetPasswordTest extends TestCase
{
    use RefreshDatabase;

    private function staff(): User
    {
        $lender = Lender::create(['name' => 'Portal MFI', 'type' => 'mfi', 'licence_number' => 'LIC-P', 'status' => 'active']);

        return User::factory()->create(['role' => 'lender', 'lender_id' => $lender->id, 'email' => 'staff@portal.test']);
    }

    public function test_a_lenders_link_points_to_the_lender_portal(): void  // TC-A16
    {
        config(['services.portal.url' => 'http://portal.test:5000']);
        Notification::fake();
        $staff = $this->staff();

        Password::sendResetLink(['email' => $staff->email]);

        Notification::assertSentTo($staff, ResetPassword::class, function ($n) use ($staff) {
            $url = $n->toMail($staff)->actionUrl;

            return str_starts_with($url, 'http://portal.test:5000/?')
                && str_contains($url, 'token=') && str_contains($url, 'email=staff%40portal.test');
        });
    }

    public function test_a_borrowers_link_does_not_point_to_the_portal(): void  // TC-A17
    {
        config(['services.portal.url' => 'http://portal.test:5000']);
        Notification::fake();
        $borrower = User::factory()->create(['role' => 'borrower']);

        Password::sendResetLink(['email' => $borrower->email]);

        Notification::assertSentTo($borrower, ResetPassword::class, fn ($n) => ! str_starts_with($n->toMail($borrower)->actionUrl, 'http://portal.test:5000'));
    }

    public function test_the_emailed_token_sets_the_password_and_the_lender_can_sign_in(): void  // TC-A18
    {
        $staff = $this->staff();
        $token = Password::createToken($staff);

        $this->postJson('/api/reset-password', [
            'token' => $token, 'email' => $staff->email, 'password' => 'NewPassw0rd!', 'password_confirmation' => 'NewPassw0rd!',
        ])->assertOk();

        $this->postJson('/api/login', ['email' => $staff->email, 'password' => 'NewPassw0rd!'])->assertOk();
    }

    public function test_a_wrong_token_does_not_set_the_password(): void  // TC-A19
    {
        $staff = $this->staff();

        $response = $this->postJson('/api/reset-password', [
            'token' => 'not-a-real-token', 'email' => $staff->email, 'password' => 'NewPassw0rd!', 'password_confirmation' => 'NewPassw0rd!',
        ]);

        $this->assertNotSame(200, $response->status());
        $login = $this->postJson('/api/login', ['email' => $staff->email, 'password' => 'NewPassw0rd!']);
        $this->assertNotSame(200, $login->status());
    }
}
