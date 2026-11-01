<?php

namespace App\Http\Controllers;

use App\Models\ScoreReport;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\Http;

/**
 * Credit Reports
 *
 * A borrower can create a PDF report of their latest score, with a verification code, to share with a
 * lender outside the app. A lender checks the code on the public verification route.
 */
class ScoreReportController extends Controller
{
    /** List Reports: the borrower's own reports, newest first. */
    public function index(Request $request): JsonResponse
    {
        $reports = ScoreReport::with('creditScore')->where('user_id', $request->user()->id)->latest('issued_at')->latest('id')->get();

        return response()->json(['reports' => $reports->map(fn ($r) => $this->present($r))]);
    }

    /** Create Report: for the latest score. Set include_drivers to add the main reasons to the report. */
    public function store(Request $request): JsonResponse
    {
        $data = $request->validate(['include_drivers' => ['sometimes', 'boolean']]);
        $score = $request->user()->creditScores()->latest('scored_at')->latest('id')->first();

        if (! $score) {
            return response()->json(['message' => 'Score a statement before creating a report.'], 422);
        }

        $report = ScoreReport::issue($request->user(), $score, (bool) ($data['include_drivers'] ?? false));

        return response()->json(['report' => $this->present($report->load('creditScore'))], 201);
    }

    /** Download PDF: builds the report PDF through the scoring service. */
    public function pdf(Request $request, ScoreReport $report): Response|JsonResponse
    {
        abort_unless($report->user_id === $request->user()->id, 404);

        if ($report->revoked_at) {
            return response()->json(['message' => 'This report was withdrawn.'], 410);
        }

        $response = Http::timeout(30)
            ->withHeaders(['X-Service-Key' => config('services.scoring.key')])
            ->post(config('services.scoring.url') . '/report', $report->load('creditScore', 'user')->pdfPayload());

        if ($response->failed()) {
            return response()->json(['message' => 'The report could not be created. Try again later.'], 502);
        }

        return response($response->body(), 200, [
            'Content-Type' => 'application/pdf',
            'Content-Disposition' => 'attachment; filename="MtaaWorks-credit-report-' . $report->code . '.pdf"',
        ]);
    }

    /** Withdraw Report: the code stops verifying. */
    public function revoke(Request $request, ScoreReport $report): JsonResponse
    {
        abort_unless($report->user_id === $request->user()->id, 404);

        if (! $report->revoked_at) {
            $report->update(['revoked_at' => now()]);
        }

        return response()->json(['message' => 'Report withdrawn.']);
    }

    /**
     * Verify Report (public)
     *
     * Anyone holding the code can check it. A valid report returns the details the PDF shows; the
     * borrower's name is shortened, and the drivers appear only if the borrower included them.
     */
    public function verify(string $code): JsonResponse
    {
        $report = ScoreReport::with(['creditScore', 'user'])->where('code', ScoreReport::normalise($code))->first();

        if (! $report) {
            return response()->json(['valid' => false, 'status' => 'not_found'], 404);
        }

        $status = $report->status();

        if ($status !== 'valid') {
            return response()->json(['valid' => false, 'status' => $status, 'issued_at' => $report->issued_at]);
        }

        $score = $report->creditScore;
        $out = [
            'valid' => true,
            'status' => 'valid',
            'code' => $report->code,
            'name' => $report->maskedName(),
            'score' => $score->score,
            'risk_tier' => $score->risk_tier,
            'high_risk' => $score->high_risk,
            'model_version' => $score->model_version,
            'scored_at' => $score->scored_at,
            'issued_at' => $report->issued_at,
            'expires_at' => $report->expires_at,
            'fingerprint' => substr($report->content_hash, 0, 16),
        ];

        if ($report->includes_drivers) {
            $out['top_drivers'] = $score->top_drivers;
        }

        return response()->json($out);
    }

    private function present(ScoreReport $r): array
    {
        return [
            'id' => $r->id,
            'code' => $r->code,
            'status' => $r->status(),
            'includes_drivers' => $r->includes_drivers,
            'issued_at' => $r->issued_at,
            'expires_at' => $r->expires_at,
            'score' => $r->creditScore?->score,
            'risk_tier' => $r->creditScore?->risk_tier,
        ];
    }
}
