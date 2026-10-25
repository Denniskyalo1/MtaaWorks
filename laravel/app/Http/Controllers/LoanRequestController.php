<?php

namespace App\Http\Controllers;

use App\Models\Lender;
use App\Models\LoanRequest;
use App\Models\ScoreAccessGrant;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

/**
 * Loan Requests (borrower)
 *
 * A borrower asks an active lender for a loan. Applying also shares the borrower's latest score
 * with that lender for 30 days, because the borrower chose to apply to that lender.
 */
class LoanRequestController extends Controller
{
    /** List Lenders: the active lenders a borrower can apply to. */
    public function lenders(): JsonResponse
    {
        return response()->json([
            'lenders' => Lender::where('status', 'active')->orderBy('name')->get(['id', 'name', 'type']),
        ]);
    }

    /** List Loan Requests: the borrower's own loan requests, newest first. */
    public function index(Request $request): JsonResponse
    {
        $loans = LoanRequest::with('lender:id,name,type')
            ->where('user_id', $request->user()->id)->latest()->get();

        return response()->json(['loan_requests' => $loans->map(fn ($l) => [
            'id' => $l->id,
            'lender' => $l->lender->only(['name', 'type']),
            'amount' => $l->amount,
            'term_months' => $l->term_months,
            'purpose' => $l->purpose,
            'status' => $l->status,
            'decision_note' => $l->decision_note,
            'requested_at' => $l->created_at,
            'responded_at' => $l->responded_at,
        ])]);
    }

    /**
     * Request a Loan
     *
     * Needs a scored statement. Shares the latest score with the lender for 30 days at the chosen
     * scope. Only one pending request per lender is allowed.
     */
    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'lender_id'   => ['required', 'integer', 'exists:lenders,id'],
            'amount'      => ['required', 'numeric', 'min:' . LoanRequest::MIN_AMOUNT, 'max:' . LoanRequest::MAX_AMOUNT],
            'term_months' => ['required', 'integer', 'min:' . LoanRequest::MIN_TERM_MONTHS, 'max:' . LoanRequest::MAX_TERM_MONTHS],
            'purpose'     => ['nullable', 'string', 'max:255'],
            'scope'       => ['sometimes', Rule::in(ScoreAccessGrant::SCOPES)],
        ]);

        $user = $request->user();
        $lender = Lender::where('status', 'active')->find($data['lender_id']);

        if (! $lender) {
            return response()->json(['message' => 'That lender is not available.'], 422);
        }

        $score = $user->creditScores()->latest('scored_at')->first();

        if (! $score) {
            return response()->json(['message' => 'Score a statement before applying for a loan.'], 422);
        }

        ScoreAccessGrant::expireDue();

        try {
            $loan = DB::transaction(function () use ($user, $lender, $score, $data) {
                $scope = $data['scope'] ?? 'score_tier';
                $grant = ScoreAccessGrant::where('lender_id', $lender->id)->where('user_id', $user->id)
                    ->whereIn('status', ['requested', 'approved'])->first();

                $shared = [
                    'status' => 'approved',
                    'credit_score_id' => $score->id,
                    'responded_at' => now(),
                    'expires_at' => now()->addDays(ScoreAccessGrant::VALIDITY_DAYS),
                ];

                if (! $grant) {
                    $grant = ScoreAccessGrant::create($shared + [
                        'lender_id' => $lender->id,
                        'user_id' => $user->id,
                        'requested_by' => $user->id,
                        'scope' => $scope,
                        'requested_at' => now(),
                    ]);
                } elseif ($grant->status === 'requested') {
                    // the lender had already asked to see the score; applying is the borrower's approval
                    $grant->update($shared + ['scope' => $scope]);
                }
                // an approved, unexpired grant is reused as it is

                return LoanRequest::create([
                    'user_id' => $user->id,
                    'lender_id' => $lender->id,
                    'score_access_grant_id' => $grant->id,
                    'amount' => $data['amount'],
                    'term_months' => $data['term_months'],
                    'purpose' => $data['purpose'] ?? null,
                    'status' => 'pending',
                ]);
            });
        } catch (UniqueConstraintViolationException) {
            return response()->json(['message' => 'You already have a pending loan request with this lender.'], 409);
        }

        return response()->json(['message' => 'Loan request sent.', 'id' => $loan->id], 201);
    }

    /** Withdraw: cancels a pending loan request. The score access stays until it expires or is revoked. */
    public function withdraw(Request $request, LoanRequest $loan): JsonResponse
    {
        abort_unless($loan->user_id === $request->user()->id, 404);

        if ($loan->status !== 'pending') {
            return response()->json(['message' => 'Only a pending request can be withdrawn.'], 409);
        }

        $loan->update(['status' => 'withdrawn', 'responded_at' => now()]);

        return response()->json(['message' => 'Loan request withdrawn.']);
    }
}
