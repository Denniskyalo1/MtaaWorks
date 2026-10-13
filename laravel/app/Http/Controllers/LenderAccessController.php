<?php

namespace App\Http\Controllers;

use App\Mail\AccessRequestedMail;
use App\Models\ScoreAccessGrant;
use App\Models\User;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Mail;
use Illuminate\Validation\Rule;

/**
 * Lender Access
 *
 * Lender staff request and use borrower-approved access to scores.
 */
class LenderAccessController extends Controller
{
    /** Request Access: asks a borrower for permission to see their score. The reply is the same whether or not the borrower exists. */
    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'borrower_email' => ['required', 'email', 'max:255'],
            'scope' => ['required', Rule::in(ScoreAccessGrant::SCOPES)],
        ]);

        $staff = $request->user();
        $lender = $staff->lender;

        if (! $lender || $lender->status !== 'active') {
            return response()->json(['message' => 'Your lender account is not active.'], 403);
        }

        ScoreAccessGrant::expireDue();

        $borrower = User::where('email', $data['borrower_email'])->where('role', User::ROLE_BORROWER)->first();

        if ($borrower) {
            try {
                ScoreAccessGrant::create([
                    'lender_id' => $lender->id,
                    'user_id' => $borrower->id,
                    'requested_by' => $staff->id,
                    'scope' => $data['scope'],
                    'status' => 'requested',
                    'requested_at' => now(),
                ]);

                try {
                    Mail::to($borrower->email)->send(new AccessRequestedMail($lender->name));
                } catch (\Throwable $e) {
                    report($e);
                }
            } catch (UniqueConstraintViolationException) {
                // an open request or grant already exists: say nothing different
            }
        }

        return response()->json(['message' => 'If the borrower is registered, the request has been sent.'], 202);
    }

    /** List Requests: this lender's requests and grants. Borrower details appear only once approved. */
    public function index(Request $request): JsonResponse
    {
        ScoreAccessGrant::expireDue();

        $grants = ScoreAccessGrant::with('borrower:id,name,email')
            ->where('lender_id', $request->user()->lender_id)
            ->latest('requested_at')->get();

        return response()->json(['grants' => $grants->map(fn ($g) => [
            'id' => $g->id,
            'status' => $g->status,
            'scope' => $g->scope,
            'requested_at' => $g->requested_at,
            'responded_at' => $g->responded_at,
            'expires_at' => $g->expires_at,
            'borrower' => $g->status === 'approved' ? $g->borrower->only(['name', 'email']) : null,
        ])]);
    }

    /** View Score: the approved score for one grant. */
    public function show(Request $request, ScoreAccessGrant $grant): JsonResponse
    {
        ScoreAccessGrant::expireDue();
        $grant->refresh();

        abort_unless($grant->lender_id === $request->user()->lender_id, 404);

        if ($request->user()->lender?->status !== 'active' || ! $grant->isUsable() || ! $grant->creditScore) {
            return response()->json(['message' => 'Access is not approved, has expired, or was revoked.'], 403);
        }

        $score = $grant->creditScore;
        $grant->increment('view_count', 1, ['last_viewed_at' => now()]);

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

        return response()->json(['score' => $out]);
    }
}