<?php

namespace App\Http\Controllers;

use App\Models\User;
use Illuminate\Auth\Events\Verified;
use Illuminate\Http\Request;

class EmailVerificationController extends Controller
{

    /**
 * Verify Email
 * 
 *
 * Allows users to verify their email addresses.
 */
    public function verify(Request $request, string $id, string $hash)
    {
       $user = User::find($id);

       if(! $user || !hash_equals(sha1($user->getEmailForVerification()), $hash)){
        return response()->json([
            'message' => 'Invalid verification link.',
        ], 400);
       }

       if ($user->hasVerifiedEmail()) {
            return response()->json([
                'message' => 'Email already verified.',
            ]);
        }

        if ($user->markEmailAsVerified()) {
            event(new Verified($user));
        }

        return response()->json([
            'message' => 'Email verified successfully.',
        ]);
       
    }
    
     /**
 * Resend Verification Email
 * 
 *
 * Allows users to request a new verification email.
 */
    public function resend(Request $request)
    {
        $user = $request->user();

         if ($user->hasVerifiedEmail()) {
            return response()->json([
                'message' => 'Email already verified.',
            ]);
        }

        $user->sendEmailVerificationNotification();

        return response()->json([
            'message' => 'Verification email sent.',
        ]);

    }
    
}
