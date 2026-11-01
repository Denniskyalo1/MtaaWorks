<?php

namespace Tests\Feature;

use App\Models\Lender;
use App\Models\LoanRequest;
use App\Models\ScoreAccessGrant;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class LenderPortfolioTest extends TestCase
{
    use RefreshDatabase;

    private function lender(string $name = 'Portfolio MFI'): Lender
    {
        return Lender::create(['name' => $name, 'type' => 'mfi', 'licence_number' => 'LIC-' . $name, 'status' => 'active']);
    }

    private function grantFor(Lender $lender, string $tier, float $score, string $scope = 'score_tier', string $status = 'approved', bool $expired = false, bool $high = false)
    {
        $borrower = User::factory()->create(['role' => 'borrower']);
        $statement = $borrower->statements()->create(['period_start' => '2026-01-01', 'period_end' => '2026-06-30', 'validation' => []]);
        $cs = $statement->creditScore()->create([
            'user_id' => $borrower->id, 'default_probability' => 0.1, 'score' => $score, 'risk_tier' => $tier, 'high_risk' => $high,
            'top_drivers' => [['feature' => 'bill_payment_consistency', 'contribution' => -0.4], ['feature' => 'outflow_to_inflow_ratio', 'contribution' => 0.3]],
            'features' => [], 'model_version' => '1.0.0', 'scored_at' => now(),
        ]);
        $staff = User::where('lender_id', $lender->id)->first() ?? User::factory()->create(['role' => 'lender', 'lender_id' => $lender->id]);

        $grant = ScoreAccessGrant::create([
            'lender_id' => $lender->id, 'user_id' => $borrower->id, 'requested_by' => $staff->id, 'scope' => $scope, 'status' => $status,
            'credit_score_id' => $cs->id, 'requested_at' => now(), 'responded_at' => now(),
            'expires_at' => $expired ? now()->subDay() : now()->addDays(20),
        ]);
        $grant->forceFill(['view_count' => 2])->save();   // view_count is not mass assignable

        return $grant;
    }

    public function test_portfolio_counts_only_usable_grants_of_this_lender(): void  // TC-A20
    {
        $mine = $this->lender();
        $other = $this->lender('Other MFI');
        $this->grantFor($mine, 'Tier 1', 92.0);
        $this->grantFor($mine, 'Tier 2', 84.0, 'score_tier_drivers');
        $this->grantFor($mine, 'Tier 3', 70.0, 'score_tier', 'approved', false, true);
        $this->grantFor($mine, 'Tier 1', 95.0, 'score_tier', 'approved', true);        // expired
        $this->grantFor($mine, 'Tier 1', 95.0, 'score_tier', 'revoked');               // revoked
        $this->grantFor($other, 'Tier 1', 99.0);                                       // another lender

        Sanctum::actingAs(User::where('lender_id', $mine->id)->first());
        $p = $this->getJson('/api/lender/portfolio')->assertOk()->json('portfolio');

        $this->assertSame(3, $p['grants']['active']);
        $this->assertSame(1, $p['grants']['expired']);
        $this->assertSame(1, $p['grants']['revoked']);
        $this->assertSame(['Tier 1' => 1, 'Tier 2' => 1, 'Tier 3' => 1], $p['scores']['tiers']);
        $this->assertEquals(82.0, $p['scores']['average']);
        $this->assertSame(1, $p['scores']['high_risk']);
        $this->assertSame(10, $p['views']);   // 5 grants of this lender, 2 views each
    }

    public function test_drivers_come_only_from_borrowers_who_shared_them(): void  // TC-A21
    {
        $lender = $this->lender();
        $this->grantFor($lender, 'Tier 1', 90.0, 'score_tier');
        $this->grantFor($lender, 'Tier 2', 85.0, 'score_tier_drivers');

        Sanctum::actingAs(User::where('lender_id', $lender->id)->first());
        $p = $this->getJson('/api/lender/portfolio')->assertOk()->json('portfolio');

        $this->assertSame(1, $p['drivers']['borrowers_sharing_drivers']);
        $top = collect($p['drivers']['top'])->keyBy('feature');
        $this->assertSame(1, $top['bill_payment_consistency']['helping']);
        $this->assertSame(1, $top['outflow_to_inflow_ratio']['holding_back']);
    }

    public function test_loan_request_totals_and_approval_rate(): void  // TC-A22
    {
        $lender = $this->lender();
        $g = $this->grantFor($lender, 'Tier 1', 90.0);
        foreach ([['approved', 10000], ['approved', 20000], ['declined', 5000], ['pending', 7000], ['withdrawn', 1000]] as $i => [$status, $amount]) {
            $b = User::factory()->create(['role' => 'borrower']);
            LoanRequest::create(['user_id' => $b->id, 'lender_id' => $lender->id, 'score_access_grant_id' => $g->id,
                'amount' => $amount, 'term_months' => 6, 'status' => $status]);
        }

        Sanctum::actingAs(User::where('lender_id', $lender->id)->first());
        $loans = $this->getJson('/api/lender/portfolio')->assertOk()->json('portfolio.loans');

        $this->assertSame(2, $loans['approved']['count']);
        $this->assertEquals(30000, $loans['approved']['amount']);
        $this->assertSame(1, $loans['pending']['count']);
        $this->assertEquals(0.667, $loans['approval_rate']);
    }

    public function test_an_empty_portfolio_returns_zeros_and_no_average(): void  // TC-A23
    {
        $lender = $this->lender();
        Sanctum::actingAs(User::factory()->create(['role' => 'lender', 'lender_id' => $lender->id]));

        $p = $this->getJson('/api/lender/portfolio')->assertOk()->json('portfolio');
        $this->assertSame(0, $p['grants']['active']);
        $this->assertNull($p['scores']['average']);
        $this->assertNull($p['loans']['approval_rate']);
    }

    public function test_borrowers_cannot_open_the_portfolio(): void  // TC-A24
    {
        Sanctum::actingAs(User::factory()->create(['role' => 'borrower']));
        $this->getJson('/api/lender/portfolio')->assertForbidden();
    }
}
