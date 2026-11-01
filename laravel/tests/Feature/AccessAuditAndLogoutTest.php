<?php

namespace Tests\Feature;

use App\Models\Lender;
use App\Models\LoanRequest;
use App\Models\ScoreAccessEvent;
use App\Models\ScoreAccessGrant;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AccessAuditAndLogoutTest extends TestCase
{
    use RefreshDatabase;

    private function lender(): Lender
    {
        return Lender::create(['name' => 'Audit MFI', 'type' => 'mfi', 'licence_number' => 'LIC-A', 'status' => 'active']);
    }

    private function scoredBorrower(): User
    {
        $user = User::factory()->create(['role' => 'borrower']);
        $statement = $user->statements()->create(['period_start' => '2026-01-01', 'period_end' => '2026-06-30', 'validation' => []]);
        $statement->creditScore()->create([
            'user_id' => $user->id, 'default_probability' => 0.1, 'score' => 90.0, 'risk_tier' => 'Tier 1',
            'high_risk' => false, 'top_drivers' => [['feature' => 'bill_payment_consistency', 'contribution' => -0.4]],
            'features' => ['bill_payment_consistency' => 1.0], 'model_version' => '1.0.0', 'scored_at' => now(),
        ]);

        return $user;
    }

    private function approvedGrant(User $borrower, Lender $lender, string $scope = 'score_tier'): ScoreAccessGrant
    {
        $staff = User::factory()->create(['role' => 'lender', 'lender_id' => $lender->id]);

        return ScoreAccessGrant::create([
            'lender_id' => $lender->id, 'user_id' => $borrower->id, 'requested_by' => $staff->id, 'scope' => $scope,
            'status' => 'approved', 'credit_score_id' => $borrower->creditScores()->first()->id,
            'requested_at' => now(), 'responded_at' => now(), 'expires_at' => now()->addDays(30),
        ]);
    }

    public function test_lender_logout_revokes_the_token_on_the_server(): void  // TC-A10
    {
        $lender = $this->lender();
        $staff = User::factory()->create(['role' => 'lender', 'lender_id' => $lender->id]);
        $token = $staff->createToken('portal')->plainTextToken;

        $this->withToken($token)->getJson('/api/lender/access-requests')->assertOk();
        $this->withToken($token)->postJson('/api/logout')->assertOk();

        $this->app['auth']->forgetGuards();
        $this->withToken($token)->getJson('/api/lender/access-requests')->assertUnauthorized();
        $this->assertSame(0, $staff->tokens()->count());
    }

    public function test_borrower_logout_still_works(): void  // TC-A11
    {
        $borrower = User::factory()->create(['role' => 'borrower']);
        $token = $borrower->createToken('app')->plainTextToken;

        $this->withToken($token)->postJson('/api/logout')->assertOk();
        $this->assertSame(0, $borrower->tokens()->count());
    }

    public function test_opening_a_score_is_logged_and_shown_to_the_borrower(): void  // TC-A12
    {
        $lender = $this->lender();
        $borrower = $this->scoredBorrower();
        $grant = $this->approvedGrant($borrower, $lender);
        $staff = User::where('lender_id', $lender->id)->first();

        Sanctum::actingAs($staff);
        $this->getJson('/api/lender/grants/' . $grant->id . '/score')->assertOk();
        $this->getJson('/api/lender/grants/' . $grant->id . '/score')->assertOk();

        $this->assertSame(2, ScoreAccessEvent::where('score_access_grant_id', $grant->id)->count());

        Sanctum::actingAs($borrower);
        $events = $this->getJson('/api/access-history')->assertOk()->json('events');
        $this->assertCount(2, $events);
        $this->assertSame('Audit MFI', $events[0]['lender']['name']);
        $this->assertSame('score_tier', $events[0]['scope']);
    }

    public function test_opening_a_loan_request_is_logged(): void  // TC-A13
    {
        $lender = $this->lender();
        $borrower = $this->scoredBorrower();
        $grant = $this->approvedGrant($borrower, $lender);
        $loan = LoanRequest::create(['user_id' => $borrower->id, 'lender_id' => $lender->id, 'score_access_grant_id' => $grant->id,
            'amount' => 5000, 'term_months' => 3, 'status' => 'pending']);

        Sanctum::actingAs(User::where('lender_id', $lender->id)->first());
        $this->getJson('/api/lender/loan-requests/' . $loan->id)->assertOk();

        $this->assertSame(1, ScoreAccessEvent::where('score_access_grant_id', $grant->id)->count());
    }

    public function test_a_borrower_sees_only_views_of_their_own_score(): void  // TC-A14
    {
        $lender = $this->lender();
        $mine = $this->scoredBorrower();
        $other = $this->scoredBorrower();
        $grant = $this->approvedGrant($other, $lender);
        ScoreAccessEvent::record($grant, User::where('lender_id', $lender->id)->first());

        Sanctum::actingAs($mine);
        $this->assertCount(0, $this->getJson('/api/access-history')->assertOk()->json('events'));
    }

    public function test_scores_are_encrypted_at_rest_and_read_back_unchanged(): void  // TC-A15
    {
        $borrower = $this->scoredBorrower();
        $raw = DB::table('credit_scores')->first();

        foreach (['score', 'default_probability', 'top_drivers', 'features'] as $column) {
            $this->assertStringNotContainsString('bill_payment', (string) $raw->$column);
            $this->assertStringStartsWith('eyJ', (string) $raw->$column);   // an encrypted payload, not plain text
        }
        $this->assertSame('Tier 1', $raw->risk_tier);

        $score = $borrower->creditScores()->first();
        $this->assertSame('90.00', $score->score);
        $this->assertSame('0.10000', $score->default_probability);
        $this->assertSame('bill_payment_consistency', $score->top_drivers[0]['feature']);
    }
}
