<?php

namespace App\Http\Controllers;

use App\Models\Consent;
use App\Models\CreditScore;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;

/**
 * Scores
 *
 * Credit scores for the logged in borrower.
 */
class ScoreController extends Controller
{
    /**
     * Score a Statement
     *
     * Sends an M-Pesa statement PDF to the scoring service and stores the result.
     * Requires active consent for statement analysis. The PDF and its password are not stored.
     */
    public function store(Request $request): JsonResponse
    {
        $request->validate([
            'statement' => ['required', 'file', 'mimes:pdf', 'max:10240'],
            'password'  => ['required', 'string', 'max:100'],
        ]);

        $user = $request->user();

        if (! $user->consents()->active()->where('purpose', Consent::STATEMENT_ANALYSIS)->exists()) {
            return response()->json(['message' => 'Consent for statement analysis is required.'], 403);
        }

        try {
            $response = Http::timeout(60)
                ->withHeaders(['X-Service-Key' => config('services.scoring.key')])
                ->attach('file', file_get_contents($request->file('statement')->getRealPath()), 'statement.pdf')
                ->post(config('services.scoring.url') . '/score-statement', [
                    'password' => $request->input('password'),
                ]);
        } catch (ConnectionException) {
            return response()->json(['message' => 'The scoring service is unavailable. Try again later.'], 503);
        }

        if ($response->serverError() || in_array($response->status(), [401, 403], true)) {
            return response()->json(['message' => 'The scoring service could not process the request.'], 502);
        }

        if ($response->clientError()) {
            $detail = $response->json('detail');
            return response()->json([
                'message' => is_string($detail) ? $detail : 'The statement could not be processed.',
            ], 422);
        }

        $data = $response->json();

        if (! isset($data['result'], $data['features'], $data['validation'])) {
            return response()->json(['message' => 'The scoring service returned an unexpected response.'], 502);
        }

        $result = $data['result'];
        $validation = array_merge($data['validation'], [
            'months_in_statement' => $data['months_in_statement'] ?? null,
            'full_months_used'    => $data['full_months_used'] ?? null,
        ]);

        $score = DB::transaction(function () use ($user, $data, $result, $validation) {
            $statement = $user->statements()->create([
                'period_start' => $validation['period_start'] ?? null,
                'period_end'   => $validation['period_end'] ?? null,
                'validation'   => $validation,
            ]);

            return $statement->creditScore()->create([
                'user_id'               => $user->id,
                'default_probability'   => $result['probability_of_default'],
                'score'                 => $result['score'],
                'risk_tier'             => $result['tier'],
                'high_risk'             => $result['flagged_high_risk'],
                'top_drivers'           => $result['top_drivers'],
                'features'              => $data['features'],
                'imputed_features'      => $data['imputed_features'] ?? [],
                'out_of_range_features' => $result['out_of_range_features'] ?? [],
                'model_version'         => $result['model_version'],
                'scored_at'             => now(),
            ]);
        });

        return response()->json(['message' => 'Statement scored.', 'score' => $this->present($score)], 201);
    }

    /** List Scores: the borrower's own scoring history, newest first. */
    public function index(Request $request): JsonResponse
    {
        $scores = $request->user()->creditScores()->latest('scored_at')->get();

        return response()->json(['scores' => $scores->map(fn ($s) => $this->present($s))]);
    }

    /** Latest Score */
    public function latest(Request $request): JsonResponse
    {
        $score = $request->user()->creditScores()->latest('scored_at')->first();

        if (! $score) {
            return response()->json(['message' => 'No score yet.'], 404);
        }

        return response()->json(['score' => $this->present($score)]);
    }

    private function present(CreditScore $s): array
    {
        return $s->only([
            'id', 'score', 'risk_tier', 'high_risk', 'default_probability', 'top_drivers',
            'features', 'imputed_features', 'out_of_range_features', 'model_version', 'scored_at',
        ]);
    }
}