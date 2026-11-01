<?php

namespace App\Http\Controllers;

use App\Models\User;
use Google\Client;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

class GoogleAuthController extends Controller
{

   /**
 * Login with Google
 * 
 *
 * Allows users to login using their google account.
 */
    public function login(Request $request): JsonResponse
    {
        $request->validate(['id_token' => ['required', 'string']]);

        // 1. Verify the token with Google
        $client = new Client(['client_id' => config('services.google.client_id')]);

           try {
       $payload = $client->verifyIdToken($request->input('id_token'));
   } catch (\Throwable $e) {
       Log::error('Google verify threw: ' . $e->getMessage());
       $payload = null;
   }

   if (!$payload) {
       Log::warning('Google verifyIdToken returned no payload');
   }

        if (!$payload || !($payload['email_verified'] ?? false)) {
            return response()->json(['message' => 'Invalid Google token.'], 401);
        }

        // 2. Find the user: by Google ID first, then by email
        $user = User::where('google_id', $payload['sub'])->first()
            ?? User::where('email', $payload['email'])->first();

        // 3. Link an existing account, or create a new one
        if ($user) {
            if (is_null($user->email_verified_at)) {
                $user->password = null; // see note below
            }
            $user->google_id = $payload['sub'];
            $user->avatar ??= $payload['picture'] ?? null;
            $user->email_verified_at ??= now();
        } else {
            $user = new User();
            $user->name = $payload['name'] ?? 'User';
            $user->email = $payload['email'];
            $user->google_id = $payload['sub'];
            $user->avatar = $payload['picture'] ?? null;
            $user->email_verified_at = now();
        }

        $user->save();

        // 4. Issue the Sanctum token
        return response()->json([
            'token' => $user->createToken('mobile')->plainTextToken,
            'user' => $user,
            'needs_profile_completion' => blank($user->national_id),
      ]);
    }
}