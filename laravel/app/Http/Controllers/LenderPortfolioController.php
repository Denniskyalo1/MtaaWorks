<?php

namespace App\Http\Controllers;

use App\Models\LoanRequest;
use App\Models\ScoreAccessGrant;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Portfolio (lender)
 *
 * Summary figures for the borrowers whose scores this lender may currently see. Only grants that
 * are approved and not expired or revoked are counted, and no borrower is named.
 */
class LenderPortfolioController extends Controller
{
    /** Portfolio Summary: counts by tier, average score, main drivers and loan request totals. */
    public function show(Request $request): JsonResponse
    {
        abort_unless($request->user()->lender?->status === 'active', 403);

        $lenderId = $request->user()->lender_id;
        ScoreAccessGrant::expireDue();

        $grants = ScoreAccessGrant::with('creditScore')->where('lender_id', $lenderId)->get();
        $usable = $grants->filter(fn ($g) => $g->isUsable() && $g->creditScore);

        $tiers = ['Tier 1' => 0, 'Tier 2' => 0, 'Tier 3' => 0];
        foreach ($usable as $g) {
            $tier = $g->creditScore->risk_tier;
            $tiers[$tier] = ($tiers[$tier] ?? 0) + 1;
        }

        // Drivers are counted only for grants where the borrower chose to share them
        $driverCounts = [];
        $withDrivers = $usable->filter(fn ($g) => $g->scope === 'score_tier_drivers');
        foreach ($withDrivers as $g) {
            foreach ((array) $g->creditScore->top_drivers as $d) {
                $feature = $d['feature'] ?? null;
                if (! $feature) {
                    continue;
                }
                $driverCounts[$feature] ??= ['feature' => $feature, 'label' => ucfirst(str_replace('_', ' ', $feature)), 'helping' => 0, 'holding_back' => 0];
                $driverCounts[$feature][((float) ($d['contribution'] ?? 0)) < 0 ? 'helping' : 'holding_back']++;
            }
        }
        $drivers = collect($driverCounts)->sortByDesc(fn ($d) => $d['helping'] + $d['holding_back'])->take(5)->values();

        $loans = LoanRequest::where('lender_id', $lenderId)->get();
        $byStatus = fn (string $s) => [
            'count' => $loans->where('status', $s)->count(),
            'amount' => round((float) $loans->where('status', $s)->sum('amount'), 2),
        ];
        $decided = $loans->whereIn('status', ['approved', 'declined'])->count();

        return response()->json(['portfolio' => [
            'generated_at' => now(),
            'grants' => [
                'active' => $usable->count(),
                'pending' => $grants->where('status', 'requested')->count(),
                'expired' => $grants->where('status', 'expired')->count(),
                'revoked' => $grants->where('status', 'revoked')->count(),
                'declined' => $grants->where('status', 'declined')->count(),
            ],
            'scores' => [
                'count' => $usable->count(),
                'average' => $usable->isEmpty() ? null : round($usable->avg(fn ($g) => (float) $g->creditScore->score), 1),
                'high_risk' => $usable->filter(fn ($g) => $g->creditScore->high_risk)->count(),
                'tiers' => $tiers,
            ],
            'drivers' => ['borrowers_sharing_drivers' => $withDrivers->count(), 'top' => $drivers],
            'loans' => [
                'pending' => $byStatus('pending'),
                'approved' => $byStatus('approved'),
                'declined' => $byStatus('declined'),
                'withdrawn' => $byStatus('withdrawn'),
                'approval_rate' => $decided === 0 ? null : round($loans->where('status', 'approved')->count() / $decided, 3),
            ],
            'views' => (int) $grants->sum('view_count'),
        ]]);
    }
}
