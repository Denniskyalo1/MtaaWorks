<?php

namespace Tests\Feature;

use App\Models\Consent;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ScoreIdentityTest extends TestCase
{
    use RefreshDatabase;

    private function fakeScoringService(int $status = 200, ?array $body = null): void
    {
        config(['services.scoring.url' => 'http://scoring.test', 'services.scoring.key' => 'k']);
        $ok = [
            'result' => ['probability_of_default' => 0.1, 'score' => 90.0, 'tier' => 'Tier 1', 'flagged_high_risk' => false,
                'top_drivers' => [], 'out_of_range_features' => [], 'model_version' => '1.0.0'],
            'features' => [], 'imputed_features' => [], 'months_in_statement' => 7, 'full_months_used' => 5,
            'validation' => ['rows_read' => 10, 'period_start' => '2026-01-01', 'period_end' => '2026-07-31', 'files_read' => 1, 'identity_checked' => true],
        ];
        Http::fake(['scoring.test/*' => Http::response($body ?? $ok, $status)]);
    }

    private function borrower(array $extra = []): User
    {
        $user = User::factory()->create(array_merge(['role' => 'borrower', 'name' => 'John Kamau Doe', 'phone_number' => '0712345678'], $extra));
        Consent::create(['user_id' => $user->id, 'purpose' => Consent::STATEMENT_ANALYSIS, 'policy_version' => '1.0', 'granted_at' => now()]);
        Sanctum::actingAs($user);

        return $user;
    }

    private function pdf(string $name = 'a.pdf'): UploadedFile
    {
        return UploadedFile::fake()->create($name, 50, 'application/pdf');
    }

    public function test_the_account_name_and_verified_phone_go_to_the_scoring_service(): void  // TC-A37
    {
        $this->fakeScoringService();
        $this->borrower(['phone_verified_at' => now()]);

        $this->post('/api/scores', ['statement' => $this->pdf(), 'password' => 'x'], ['Accept' => 'application/json'])->assertCreated();

        Http::assertSent(fn ($r) =>
    str_contains($r->body(), 'name="expected_name"')
    && str_contains($r->body(), 'John Kamau Doe')
    && str_contains($r->body(), 'name="expected_phone"')
    && str_contains($r->body(), '0712345678')
);
    }

    public function test_an_unverified_phone_is_not_used_for_the_check(): void  // TC-A38
    {
        $this->fakeScoringService();
        $this->borrower();

        $this->post('/api/scores', ['statement' => $this->pdf(), 'password' => 'x'], ['Accept' => 'application/json'])->assertCreated();

        Http::assertSent(fn ($r) =>
    str_contains($r->body(), 'name="expected_name"')
    && str_contains($r->body(), 'John Kamau Doe')
    && str_contains($r->body(), 'name="expected_phone"')
    && ! str_contains($r->body(), '0712345678')
);
    }

    public function test_the_check_also_applies_when_several_statements_are_sent(): void  // TC-A39
    {
        $this->fakeScoringService();
        $this->borrower(['phone_verified_at' => now()]);

        $this->post('/api/scores', ['statements' => [$this->pdf('a.pdf'), $this->pdf('b.pdf')], 'passwords' => ['x', 'y']], ['Accept' => 'application/json'])->assertCreated();

        Http::assertSent(fn ($r) =>
    str_ends_with($r->url(), '/score-statements')
    && str_contains($r->body(), 'name="expected_name"')
    && str_contains($r->body(), 'John Kamau Doe')
);
    }

    public function test_a_name_mismatch_is_passed_back_to_the_borrower_and_nothing_is_stored(): void  // TC-A40
    {
        $this->fakeScoringService(422, ['detail' => 'The customer name on the statement does not match the name on your MtaaWorks account.']);
        $user = $this->borrower();

        $this->post('/api/scores', ['statement' => $this->pdf(), 'password' => 'x'], ['Accept' => 'application/json'])
            ->assertStatus(422)->assertJsonPath('message', 'The customer name on the statement does not match the name on your MtaaWorks account.');

        $this->assertSame(0, $user->creditScores()->count());
    }

    public function test_scoring_is_refused_when_verification_is_required_and_phone_is_unverified(): void
    {
        config(['services.scoring.require_phone_verification' => true]);
        $this->fakeScoringService();
        $this->borrower();

        $this->post('/api/scores', ['statement' => $this->pdf(), 'password' => 'x'], ['Accept' => 'application/json'])
            ->assertForbidden();
    }
}       