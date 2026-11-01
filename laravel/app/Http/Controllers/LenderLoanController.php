<?php

namespace App\Http\Controllers;

use App\Models\LoanRequest;
use App\Models\ScoreAccessGrant;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Loan Requests (lender)
 *
 * Lender staff see the loan requests addressed to their organisation and record a decision.
 * A decision is an answer to the borrower. Loan agreements and payments are outside the system.
 */
class LenderLoanController extends Controller
{
    /** List Loan Requests: requests addressed to this lender. The score is not included here. */
    public function index(Request $request): JsonResponse
    {
        $loans = LoanRequest::with('borrower:id,name,email')
            ->where('lender_id', $request->user()->lender_id)->latest()->get();

        return response()->json(['loan_requests' => $loans->map(fn ($l) => $this->summary($l))]);
    }

    /** View Loan Request: the request with the borrower's score at the scope the borrower shared. Counts as a view. */
    public function show(Request $request, LoanRequest $loan): JsonResponse
    {
        $this->authorise($request, $loan);
        ScoreAccessGrant::expireDue();

        $grant = $loan->grant?->fresh();

        if (! $grant || ! $grant->isUsable() || ! $grant->creditScore) {
            return response()->json(['message' => 'Access to this borrower\'s score has expired or was revoked.'], 403);
        }

        $score = $grant->creditScore;
        $grant->increment('view_count', 1, ['last_viewed_at' => now()]);
        \App\Models\ScoreAccessEvent::record($grant, $request->user());

        $out = [
            'score' => $score->score,
            'risk_tier' => $score->risk_tier,
            'high_risk' => $score->high_risk,
            'model_version' => $score->model_version,
            'scored_at' => $score->scored_at,
            'access_expires_at' => $grant->expires_at,
        ];

        if ($grant->scope === 'score_tier_drivers') {
            $out['top_drivers'] = $score->top_drivers;
        }

        return response()->json(['loan_request' => $this->summary($loan->load('borrower:id,name,email')), 'score' => $out]);
    }

    /** Approve: the lender accepts the request in principle. Terms are agreed outside MtaaWorks. */
    public function approve(Request $request, LoanRequest $loan): JsonResponse
    {
        return $this->decide($request, $loan, 'approved');
    }

    /** Decline */
    public function decline(Request $request, LoanRequest $loan): JsonResponse
    {
        return $this->decide($request, $loan, 'declined');
    }

    private function decide(Request $request, LoanRequest $loan, string $status): JsonResponse
    {
        $this->authorise($request, $loan);
        $data = $request->validate(['note' => ['nullable', 'string', 'max:255']]);

        if ($loan->status !== 'pending') {
            return response()->json(['message' => 'This request is no longer pending.'], 409);
        }

        $loan->update(['status' => $status, 'decision_note' => $data['note'] ?? null, 'responded_at' => now()]);

        return response()->json(['message' => $status === 'approved' ? 'Loan request approved.' : 'Loan request declined.']);
    }

    private function authorise(Request $request, LoanRequest $loan): void
    {
        abort_unless($loan->lender_id === $request->user()->lender_id, 404);
        abort_unless($request->user()->lender?->status === 'active', 403);
    }

    private function summary(LoanRequest $l): array
    {
        return [
            'id' => $l->id,
            'status' => $l->status,
            'amount' => $l->amount,
            'term_months' => $l->term_months,
            'purpose' => $l->purpose,
            'decision_note' => $l->decision_note,
            'requested_at' => $l->created_at,
            'responded_at' => $l->responded_at,
            'borrower' => $l->borrower->only(['name', 'email']),
        ];
    }
}
