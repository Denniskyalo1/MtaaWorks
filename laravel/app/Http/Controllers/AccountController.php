<?php

namespace App\Http\Controllers;

use App\Mail\AccountDeletionCodeMail;
use App\Models\AccountDeletionCode;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Mail;

/**
 * Account
 *
 * Account and security actions for the logged in user.
 */
class AccountController extends Controller
{
    /**
     * Request Account Deletion
     *
     * Emails a 6-digit code to the user's verified email address. The code expires in 10 minutes.
     */
    public function requestDeletion(Request $request): JsonResponse
    {
        $user = $request->user();

        if ($user->role === User::ROLE_ADMIN) {
             return response()->json(['message' => 'Admin accounts cannot be deleted here.'], 403);
     }

        if (! $user->hasVerifiedEmail()) {
            return response()->json(['message' => 'Verify your email first.'], 403);
        }

        $code = (string) random_int(100000, 999999);

        AccountDeletionCode::updateOrCreate(
            ['user_id' => $user->id],
            [
                'code_hash'  => hash_hmac('sha256', $code, config('app.key')),
                'attempts'   => 0,
                'expires_at' => now()->addMinutes(10),
            ]
        );

        Mail::to($user->email)->send(new AccountDeletionCodeMail($code));

        return response()->json(['message' => 'Verification code sent to your email.']);
    }

    /**
     * Delete Account
     *
     * Permanently deletes the account after the emailed code is confirmed.
     */
    public function deleteAccount(Request $request): JsonResponse
    {
        $request->validate(['code' => ['required', 'digits:6']]);

        $user = $request->user();
        $record = AccountDeletionCode::where('user_id', $user->id)->first();

        if (! $record || $record->expires_at->isPast() || $record->attempts >= 5) {
            return response()->json(['message' => 'Code invalid or expired.'], 422);
        }

        $record->increment('attempts');

        $expected = hash_hmac('sha256', $request->code, config('app.key'));

        if (! hash_equals($record->code_hash, $expected)) {
            return response()->json(['message' => 'Code invalid or expired.'], 422);
        }

        DB::transaction(function () use ($user) {
            $user->tokens()->delete();
            $user->delete(); // cascades the deletion code row
        });

        return response()->json(['message' => 'Account deleted successfully.']);
    }
}