<?php

namespace Tests\Feature;

use App\Models\CreditScore;
use App\Models\ScoreReport;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ScoreReportTest extends TestCase
{
    use RefreshDatabase;

    private function scoredBorrower(string $name = 'Dennis Kyalo Kasyoki'): User
    {
        $user = User::factory()->create(['role' => 'borrower', 'name' => $name]);
        $statement = $user->statements()->create(['period_start' => '2026-01-01', 'period_end' => '2026-06-30', 'validation' => []]);
        $statement->creditScore()->create([
            'user_id' => $user->id, 'default_probability' => 0.1, 'score' => 90.1, 'risk_tier' => 'Tier 1', 'high_risk' => false,
            'top_drivers' => [['feature' => 'bill_payment_consistency', 'contribution' => -0.4]], 'features' => [],
            'model_version' => '1.0.0', 'scored_at' => now(),
        ]);

        return $user;
    }

    public function test_a_borrower_creates_a_report_with_a_code(): void  // TC-A25
    {
        $user = $this->scoredBorrower();
        Sanctum::actingAs($user);

        $r = $this->postJson('/api/reports')->assertCreated()->json('report');

        $this->assertMatchesRegularExpression('/^MWR-[A-Z2-9]{4}-[A-Z2-9]{4}-[A-Z2-9]{4}$/', $r['code']);
        $this->assertSame('valid', $r['status']);
        $this->assertSame('Tier 1', $r['risk_tier']);
        $this->assertEqualsWithDelta(30, now()->diffInDays($r['expires_at'], false), 1);
    }

    public function test_a_report_needs_a_scored_statement(): void  // TC-A26
    {
        Sanctum::actingAs(User::factory()->create(['role' => 'borrower']));
        $this->postJson('/api/reports')->assertStatus(422);
    }

    public function test_the_pdf_is_built_through_the_scoring_service(): void  // TC-A27
    {
        config(['services.scoring.url' => 'http://scoring.test', 'services.scoring.key' => 'k']);
        Http::fake(['scoring.test/report' => Http::response('%PDF-1.4 fake', 200, ['Content-Type' => 'application/pdf'])]);
        $user = $this->scoredBorrower();
        Sanctum::actingAs($user);
        $id = $this->postJson('/api/reports')->json('report.id');

        $response = $this->get('/api/reports/' . $id . '/pdf', ['Accept' => 'application/json']);

        $response->assertOk()->assertHeader('Content-Type', 'application/pdf');
        $this->assertStringStartsWith('%PDF', $response->getContent());
        Http::assertSent(function ($request) {
            $body = $request->data();

            return str_ends_with($request->url(), '/report') && $body['name'] === 'Dennis K.' && $body['drivers'] === null
                && ! array_key_exists('national_id', $body) && ! array_key_exists('email', $body);
        });
    }

    public function test_drivers_go_into_the_pdf_only_when_included(): void  // TC-A28
    {
        config(['services.scoring.url' => 'http://scoring.test', 'services.scoring.key' => 'k']);
        Http::fake(['scoring.test/report' => Http::response('%PDF-1.4 fake', 200)]);
        Sanctum::actingAs($this->scoredBorrower());
        $id = $this->postJson('/api/reports', ['include_drivers' => true])->json('report.id');

        $this->get('/api/reports/' . $id . '/pdf', ['Accept' => 'application/json'])->assertOk();

        Http::assertSent(fn ($request) => ($request->data()['drivers'][0]['label'] ?? null) === 'Bill payment consistency'
            && $request->data()['drivers'][0]['helping'] === true);
    }

    public function test_another_borrower_cannot_download_or_withdraw_a_report(): void  // TC-A29
    {
        $owner = $this->scoredBorrower();
        Sanctum::actingAs($owner);
        $id = $this->postJson('/api/reports')->json('report.id');

        Sanctum::actingAs($this->scoredBorrower('Someone Else'));
        $this->getJson('/api/reports/' . $id . '/pdf')->assertNotFound();
        $this->postJson('/api/reports/' . $id . '/revoke')->assertNotFound();
        $this->assertCount(0, $this->getJson('/api/reports')->json('reports'));
    }

    public function test_a_valid_code_verifies_with_a_shortened_name_and_no_drivers(): void  // TC-A30
    {
        Sanctum::actingAs($this->scoredBorrower());
        $code = $this->postJson('/api/reports')->json('report.code');
        $this->app['auth']->forgetGuards();

        $v = $this->getJson('/api/reports/verify/' . $code)->assertOk()->json();

        $this->assertTrue($v['valid']);
        $this->assertSame('Dennis K.', $v['name']);
        $this->assertSame('Tier 1', $v['risk_tier']);
        $this->assertSame('90.10', $v['score']);
        $this->assertArrayNotHasKey('top_drivers', $v);
    }

    public function test_a_typed_code_is_accepted_in_lower_case_with_spaces(): void  // TC-A31
    {
        Sanctum::actingAs($this->scoredBorrower());
        $code = $this->postJson('/api/reports', ['include_drivers' => true])->json('report.code');

        $typed = strtolower(str_replace('-', ' ', $code));
        $v = $this->getJson('/api/reports/verify/' . rawurlencode($typed))->assertOk()->json();

        $this->assertTrue($v['valid']);
        $this->assertSame('bill_payment_consistency', $v['top_drivers'][0]['feature']);
    }

    public function test_an_unknown_code_is_not_found(): void  // TC-A32
    {
        $this->getJson('/api/reports/verify/MWR-AAAA-BBBB-CCCC')->assertNotFound()->assertJson(['valid' => false, 'status' => 'not_found']);
    }

    public function test_a_withdrawn_report_no_longer_verifies(): void  // TC-A33
    {
        Sanctum::actingAs($this->scoredBorrower());
        $r = $this->postJson('/api/reports')->json('report');
        $this->postJson('/api/reports/' . $r['id'] . '/revoke')->assertOk();

        $v = $this->getJson('/api/reports/verify/' . $r['code'])->assertOk()->json();
        $this->assertFalse($v['valid']);
        $this->assertSame('revoked', $v['status']);
        $this->assertArrayNotHasKey('score', $v);
        $this->getJson('/api/reports/' . $r['id'] . '/pdf')->assertStatus(410);
    }

    public function test_an_expired_report_does_not_verify(): void  // TC-A34
    {
        Sanctum::actingAs($this->scoredBorrower());
        $r = $this->postJson('/api/reports')->json('report');
        ScoreReport::where('code', $r['code'])->update(['expires_at' => now()->subDay()]);

        $v = $this->getJson('/api/reports/verify/' . $r['code'])->assertOk()->json();
        $this->assertFalse($v['valid']);
        $this->assertSame('expired', $v['status']);
    }

    public function test_a_changed_score_makes_the_report_fail_verification(): void  // TC-A35
    {
        Sanctum::actingAs($this->scoredBorrower());
        $code = $this->postJson('/api/reports')->json('report.code');

        DB::table('credit_scores')->update(['risk_tier' => 'Tier 3']);     // someone edits the stored tier

        $v = $this->getJson('/api/reports/verify/' . $code)->assertOk()->json();
        $this->assertFalse($v['valid']);
        $this->assertSame('altered', $v['status']);
    }

    public function test_the_verify_route_needs_no_login_but_other_report_routes_do(): void  // TC-A36
    {
        $this->getJson('/api/reports/verify/MWR-AAAA-BBBB-CCCC')->assertNotFound();   // reachable without a token
        $this->getJson('/api/reports')->assertUnauthorized();
        $this->postJson('/api/reports')->assertUnauthorized();
    }
}
