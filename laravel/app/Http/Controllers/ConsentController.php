<?php

namespace App\Http\Controllers;


use App\Models\Consent;
use App\Models\ScoreAccessGrant;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class ConsentController extends Controller
{
     /** List Consents: the borrower's own consent history. */
    public function index(Request $request): JsonResponse
    {
        return response()->json([
            'consents' => $request->user()->consents()->latest('granted_at')
                ->get(['purpose', 'policy_version', 'granted_at', 'revoked_at']),
        ]);
    }

    /** Grant Consent: records explicit consent for one purpose. */
    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'purpose' => ['required', Rule::in(Consent::PURPOSES)],
            'policy_version' => ['required', Rule::in([Consent::CURRENT_POLICY_VERSION])],
        ]);

        try {
            $consent = $request->user()->consents()->create($data + ['granted_at' => now()]);
        } catch (UniqueConstraintViolationException) {
            return response()->json(['message' => 'Consent already granted for this purpose.'], 409);
        }

        return response()->json(['message' => 'Consent recorded.', 'consent' => $consent->only(['purpose', 'policy_version', 'granted_at'])], 201);
    }
    
    /** Revoke Consent: ends the active consent for a purpose. */
    public function destroy(Request $request, string $purpose): JsonResponse
    {
        abort_unless(in_array($purpose, Consent::PURPOSES, true), 404);

        $revoked = $request->user()->consents()->active()
            ->where('purpose', $purpose)->update(['revoked_at' => now()]);

        if (! $revoked) {
            return response()->json(['message' => 'No active consent for this purpose.'], 404);
        }

        if ($purpose === Consent::STATEMENT_ANALYSIS) {
            ScoreAccessGrant::where('user_id', $request->user()->id)->whereIn('status', ['requested', 'approved'])->update(['status' => 'revoked', 'revoked_at' => now()]);
            $request->user()->statements()->delete();
        }       
        return response()->json(['message' => 'Consent revoked.']);
        }

    
}
