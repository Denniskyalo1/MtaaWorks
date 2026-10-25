<?php

namespace Tests\Feature;

use App\Models\Consent;
use App\Models\Lender;
use App\Models\LoanRequest;
use App\Models\ScoreAccessGrant;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class LoanRequestTest extends TestCase
{
    use RefreshDatabase;

    private function lender(string $name = 'Test MFI', string $status = 'active'): Lender
    {
        return Lender::create(['name' => $name, 'type' => 'mfi', 'licence_number' => 'LIC-' . $name, 'status' => $status]);
    }

    private function staff(Lender $lender): User
    {
        return User::factory()->create(['role' => 'lender', 'lender_id' => $lender->id]);
    }

    private function scoredBorrower(): User
    {
        $user = User::factory()->create(['role' => 'borrower']);
        $statement = $user->statements()->create(['period_start' => '2026-01-01', 'period_end' => '2026-06-30', 'validation' => []]);
        $statement->creditScore()->create([
            'user_id' => $user->id, 'default_probability' => 0.1, 'score' => 90.0, 'risk_tier' => 'Tier 1',
            'high_risk' => false, 'top_drivers' => [['feature' => 'bill_payment_consistency', 'contribution' => -0.4]],
            'features' => [], 'model_version' => '1.0.0', 'scored_at' => now(),
        ]);

        return $user;
    }

    private function apply(User $borrower, Lender $lender, array $extra = [])
    {
        Sanctum::actingAs($borrower);

        return $this->postJson('/api/loan-requests', array_merge(
            ['lender_id' => $lender->id, 'amount' => 20000, 'term_months' => 6, 'purpose' => 'Stock'], $extra));
    }

    public function test_borrower_lists_only_active_lenders(): void  // TC-L01
    {
        $this->lender('Active One');
        $this->lender('Suspended One', 'suspended');
        Sanctum::actingAs($this->scoredBorrower());

        $names = collect($this->getJson('/api/lenders')->assertOk()->json('lenders'))->pluck('name');
        $this->assertSame(['Active One'], $names->all());
    }

    public function test_loan_request_needs_a_scored_statement(): void  // TC-L02
    {
        $lender = $this->lender();
        $this->apply(User::factory()->create(['role' => 'borrower']), $lender)->assertStatus(422);
    }

    public function test_applying_creates_a_pending_request_and_shares_the_score(): void  // TC-L03
    {
        $lender = $this->lender();
        $borrower = $this->scoredBorrower();

        $this->apply($borrower, $lender)->assertCreated();

        $loan = LoanRequest::firstOrFail();
        $this->assertSame('pending', $loan->status);
        $grant = ScoreAccessGrant::firstOrFail();
        $this->assertSame('approved', $grant->status);
        $this->assertSame('score_tier', $grant->scope);
        $this->assertTrue($grant->isUsable());
        $this->assertSame($grant->id, $loan->score_access_grant_id);
    }

    public function test_a_second_pending_request_to_the_same_lender_is_refused(): void  // TC-L04
    {
        $lender = $this->lender();
        $borrower = $this->scoredBorrower();
        $this->apply($borrower, $lender)->assertCreated();
        $this->apply($borrower, $lender)->assertStatus(409);
        $this->assertSame(1, LoanRequest::count());
    }

    public function test_amount_and_term_are_validated(): void  // TC-L05
    {
        $lender = $this->lender();
        $borrower = $this->scoredBorrower();
        $this->apply($borrower, $lender, ['amount' => 10])->assertStatus(422);
        $this->apply($borrower, $lender, ['term_months' => 0])->assertStatus(422);
        $this->apply($borrower, $lender, ['scope' => 'everything'])->assertStatus(422);
    }

    public function test_an_inactive_lender_cannot_be_applied_to(): void  // TC-L06
    {
        $this->apply($this->scoredBorrower(), $this->lender('Closed', 'suspended'))->assertStatus(422);
    }

    public function test_applying_approves_an_access_request_the_lender_had_already_sent(): void  // TC-L07
    {
        $lender = $this->lender();
        $borrower = $this->scoredBorrower();
        $grant = ScoreAccessGrant::create(['lender_id' => $lender->id, 'user_id' => $borrower->id, 'requested_by' => $this->staff($lender)->id,
            'scope' => 'score_tier_drivers', 'status' => 'requested', 'requested_at' => now()]);

        $this->apply($borrower, $lender, ['scope' => 'score_tier'])->assertCreated();

        $this->assertSame(1, ScoreAccessGrant::count());
        $this->assertSame('approved', $grant->fresh()->status);
    }

    public function test_lender_sees_only_its_own_requests(): void  // TC-L08
    {
        $mine = $this->lender('Mine');
        $other = $this->lender('Other');
        $borrower = $this->scoredBorrower();
        $this->apply($borrower, $mine)->assertCreated();
        $this->apply($borrower, $other)->assertCreated();
        $otherLoan = LoanRequest::where('lender_id', $other->id)->first();

        Sanctum::actingAs($this->staff($mine));
        $this->assertCount(1, $this->getJson('/api/lender/loan-requests')->assertOk()->json('loan_requests'));
        $this->getJson('/api/lender/loan-requests/' . $otherLoan->id)->assertNotFound();
    }

    public function test_lender_view_shows_the_score_at_the_shared_scope_and_counts_the_view(): void  // TC-L09
    {
        $lender = $this->lender();
        $borrower = $this->scoredBorrower();
        $this->apply($borrower, $lender)->assertCreated();
        $loan = LoanRequest::first();

        Sanctum::actingAs($this->staff($lender));
        $body = $this->getJson('/api/lender/loan-requests/' . $loan->id)->assertOk()->json();
        $this->assertSame('Tier 1', $body['score']['risk_tier']);
        $this->assertArrayNotHasKey('top_drivers', $body['score']);
        $this->assertArrayNotHasKey('features', $body['score']);
        $this->assertSame(1, $loan->grant->fresh()->view_count);
    }

    public function test_drivers_are_shown_only_when_the_borrower_chose_that_scope(): void  // TC-L10
    {
        $lender = $this->lender();
        $this->apply($this->scoredBorrower(), $lender, ['scope' => 'score_tier_drivers'])->assertCreated();

        Sanctum::actingAs($this->staff($lender));
        $this->getJson('/api/lender/loan-requests/' . LoanRequest::first()->id)->assertOk()->assertJsonStructure(['score' => ['top_drivers']]);
    }

    public function test_lender_decides_once(): void  // TC-L11
    {
        $lender = $this->lender();
        $this->apply($this->scoredBorrower(), $lender)->assertCreated();
        $loan = LoanRequest::first();

        Sanctum::actingAs($this->staff($lender));
        $this->postJson("/api/lender/loan-requests/{$loan->id}/approve", ['note' => 'Visit our branch'])->assertOk();
        $this->postJson("/api/lender/loan-requests/{$loan->id}/decline")->assertStatus(409);
        $this->assertSame('approved', $loan->fresh()->status);
        $this->assertSame('Visit our branch', $loan->fresh()->decision_note);
    }

    public function test_borrower_withdraws_only_their_own_pending_request(): void  // TC-L12
    {
        $lender = $this->lender();
        $borrower = $this->scoredBorrower();
        $this->apply($borrower, $lender)->assertCreated();
        $loan = LoanRequest::first();

        Sanctum::actingAs($this->scoredBorrower());
        $this->postJson("/api/loan-requests/{$loan->id}/withdraw")->assertNotFound();

        Sanctum::actingAs($borrower);
        $this->postJson("/api/loan-requests/{$loan->id}/withdraw")->assertOk();
        $this->postJson("/api/loan-requests/{$loan->id}/withdraw")->assertStatus(409);
    }

    public function test_revoking_access_withdraws_pending_loan_requests(): void  // TC-L13
    {
        $lender = $this->lender();
        $borrower = $this->scoredBorrower();
        $this->apply($borrower, $lender)->assertCreated();
        $loan = LoanRequest::first();

        $this->postJson('/api/access-requests/' . $loan->score_access_grant_id . '/revoke')->assertOk();

        $this->assertSame('withdrawn', $loan->fresh()->status);
        Sanctum::actingAs($this->staff($lender));
        $this->getJson('/api/lender/loan-requests/' . $loan->id)->assertStatus(403);
    }

    public function test_roles_cannot_use_each_others_loan_routes(): void  // TC-L14
    {
        $lender = $this->lender();
        Sanctum::actingAs($this->staff($lender));
        $this->postJson('/api/loan-requests', ['lender_id' => $lender->id, 'amount' => 5000, 'term_months' => 3])->assertForbidden();

        Sanctum::actingAs($this->scoredBorrower());
        $this->getJson('/api/lender/loan-requests')->assertForbidden();
    }

    public function test_several_statements_are_sent_to_the_scoring_service_together(): void  // TC-L15
    {
        config(['services.scoring.url' => 'http://scoring.test', 'services.scoring.key' => 'k']);
        Http::fake(['scoring.test/score-statements' => Http::response([
            'result' => ['probability_of_default' => 0.1, 'score' => 90.0, 'tier' => 'Tier 1', 'flagged_high_risk' => false,
                'top_drivers' => [], 'out_of_range_features' => [], 'model_version' => '1.0.0'],
            'features' => [], 'imputed_features' => [], 'months_in_statement' => 7, 'full_months_used' => 5,
            'validation' => ['rows_read' => 10, 'period_start' => '2026-01-01', 'period_end' => '2026-07-31', 'files_read' => 2],
        ])]);
        $user = User::factory()->create(['role' => 'borrower']);
        Consent::create(['user_id' => $user->id, 'purpose' => Consent::STATEMENT_ANALYSIS, 'policy_version' => '1.0', 'granted_at' => now()]);
        Sanctum::actingAs($user);

        $this->post('/api/scores', [
            'statements' => [UploadedFile::fake()->create('a.pdf', 50, 'application/pdf'), UploadedFile::fake()->create('b.pdf', 50, 'application/pdf')],
            'passwords' => ['one', 'two'],
        ], ['Accept' => 'application/json'])->assertCreated();

        Http::assertSent(fn ($r) => str_ends_with($r->url(), '/score-statements'));
        $this->assertSame(1, $user->creditScores()->count());
    }

    public function test_one_password_is_needed_for_each_statement(): void  // TC-L16
    {
        $user = User::factory()->create(['role' => 'borrower']);
        Consent::create(['user_id' => $user->id, 'purpose' => Consent::STATEMENT_ANALYSIS, 'policy_version' => '1.0', 'granted_at' => now()]);
        Sanctum::actingAs($user);

        $this->post('/api/scores', [
            'statements' => [UploadedFile::fake()->create('a.pdf', 50, 'application/pdf'), UploadedFile::fake()->create('b.pdf', 50, 'application/pdf')],
            'passwords' => ['only-one'],
        ], ['Accept' => 'application/json'])->assertStatus(422);
    }
}
