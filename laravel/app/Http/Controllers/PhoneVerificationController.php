<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use App\Services\SmsService;
use Illuminate\Support\Carbon;

class PhoneVerificationController extends Controller
{
     /**
     * Send Phone Verification Code
     *
     * Sends a 6-digit code to the logged-in user's phone number.
     */
    public function sendCode(Request $request, SmsService $sms): JsonResponse{
        $user = $request->user();

        if (empty($user->phone_number)) {
            return response()->json(['message' => 'Add a phone number first.'], 422);
        }

         if (!is_null($user->phone_verified_at)) {
            return response()->json(['message' => 'Phone number is already verified.'], 409);
        }

        $code = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);

        DB::table('phone_verification_codes')->where('user_id', $user->id)->delete();

        DB::table('phone_verification_codes')->insert([
            'user_id' => $user->id,
            'phone_number' => $user->phone_number,
            'code_hash' => hash_hmac('sha256', $code, config('app.key')),
            'attempts' => 0,
            'expires_at' => now()->addMinutes(10),
            'created_at' => now(),
        ]);

        $sent = $sms->send(
          $this->toE164($user->phone_number),
          config('app.name') . " verification code: $code. It expires in 10 minutes."
        );

        if (!$sent) {
           DB::table('phone_verification_codes')->where('user_id', $user->id)->delete();
           return response()->json(['message' => 'Could not send the SMS. Try again shortly.'], 502);
        }

        return response()->json(['message' => 'Verification code sent.']);
    }
     
    //Convert to international E.164 format
    private function toE164(string $phone)
    {
        $digits = preg_replace('/\D+/', '', $phone);

        if (str_starts_with($digits, '0')) {
            return '+254' . substr($digits, 1);
        }
        if (str_starts_with($digits, '254')) {
            return '+' . $digits;
        }
        if (strlen($digits) === 9) {
            return '+254' . $digits;
        }

        return '+' . $digits;
    }

    /**
 * Verify Phone Number
 *
 * Checks the 6-digit code the user received by SMS.
 */
public function verify(Request $request): JsonResponse
{
    $request->validate(['code' => 'required|digits:6']);

    $user = $request->user();

    if (!is_null($user->phone_verified_at)) {
        return response()->json(['message' => 'Phone number is already verified.'], 409);
    }

    $record = DB::table('phone_verification_codes')->where('user_id', $user->id)->first();

    // No code, or the number changed since the code was sent
    if (!$record || $record->phone_number !== $user->phone_number) {
        return response()->json(['message' => 'No active code. Request a new one.'], 422);
    }

    if (Carbon::parse($record->expires_at)->isPast()) {
        DB::table('phone_verification_codes')->where('id', $record->id)->delete();
        return response()->json(['message' => 'Code has expired. Request a new one.'], 422);
    }

    if ($record->attempts >= 5) {
        DB::table('phone_verification_codes')->where('id', $record->id)->delete();
        return response()->json(['message' => 'Too many attempts. Request a new code.'], 429);
    }

    $expected = hash_hmac('sha256', $request->input('code'), config('app.key'));

    if (!hash_equals($record->code_hash, $expected)) {
        DB::table('phone_verification_codes')->where('id', $record->id)->increment('attempts');
        return response()->json(['message' => 'Incorrect code.'], 422);
    }

    $user->phone_verified_at = now();
    $user->save();

    DB::table('phone_verification_codes')->where('id', $record->id)->delete();

    return response()->json([
        'message' => 'Phone number verified.',
        'phone_verified_at' => $user->phone_verified_at,
    ]);
}
}
