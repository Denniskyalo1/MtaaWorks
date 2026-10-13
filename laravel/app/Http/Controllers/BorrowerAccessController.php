<?php

namespace App\Http\Controllers;

use App\Models\ScoreAccessGrant;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Borrower Access
 *
 * Borrowers approve, decline and revoke lender access to their score.
 */
class BorrowerAccessController extends Controller
{
    /** List Requests: all lender requests and grants for the borrower, with view counts. */
    public function index(Request $request): JsonResponse
    {
        ScoreAccessGrant::expireDue();

        $grants = ScoreAccessGrant::with('lender:id,name,type')
            ->where('user_id', $request->user()->id)->latest('requested_at')->get();

        return response()->json(['requests' => $grants->map(fn ($g) => [
            'id' => $g->id,
            'lender' => $g->lender->only(['name', 'type']),
            'scope' => $g->scope,
            'status' => $g->status,
            'requested_at' => $g->requested_at,
            'expires_at' => $g->expires_at,
            'view_count' => $g->view_count,
            'last_viewed_at' => $g->last_viewed_at,
        ])]);
    }

    /** Approve: shares the borrower's latest score with the lender for 30 days. */
    public function approve(Request $request, ScoreAccessGrant $grant): JsonResponse
    {
        $this->own($request, $grant);

        if ($grant->status !== 'requested') {
            return response()->json(['message' => 'This request is no longer pending.'], 409);
        }

        $score = $request->user()->creditScores()->latest('scored_at')->first();

        if (! $score) {
            return response()->json(['message' => 'Score a statement before approving access.'], 422);
        }

        $grant->update([
            'status' => 'approved',
            'credit_score_id' => $score->id,
            'responded_at' => now(),
            'expires_at' => now()->addDays(ScoreAccessGrant::VALIDITY_DAYS),
        ]);

        return response()->json(['message' => 'Access approved.', 'expires_at' => $grant->expires_at]);
    }

    /** Decline */
    public function decline(Request $request, ScoreAccessGrant $grant): JsonResponse
    {
        $this->own($request, $grant);

        if ($grant->status !== 'requested') {
            return response()->json(['message' => 'This request is no longer pending.'], 409);
        }

        $grant->update(['status' => 'declined', 'responded_at' => now()]);

        return response()->json(['message' => 'Request declined.']);
    }

    /** Revoke: ends an approved grant immediately. */
    public function revoke(Request $request, ScoreAccessGrant $grant): JsonResponse
    {
        $this->own($request, $grant);

        if ($grant->status !== 'approved') {
            return response()->json(['message' => 'Only an approved grant can be revoked.'], 409);
        }

        $grant->update(['status' => 'revoked', 'revoked_at' => now()]);

        return response()->json(['message' => 'Access revoked.']);
    }

    private function own(Request $request, ScoreAccessGrant $grant): void
    {
        ScoreAccessGrant::expireDue();
        $grant->refresh();
        abort_unless($grant->user_id === $request->user()->id, 404);
    }
}