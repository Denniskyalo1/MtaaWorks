<?php

namespace App\Http\Controllers;

use App\Http\Requests\ForgotPasswordRequest;
use App\Http\Requests\ResetPasswordRequest;
use App\Http\Requests\UpdatePasswordRequest;
use Illuminate\Auth\Events\PasswordReset;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Password;
use Illuminate\Support\Str;

class PasswordResetController extends Controller
{
    /**
 * Change Password
 * 
 *
 * Allows users to change their password.
 */
    public function changePassword(UpdatePasswordRequest $request)
    {
        $user = $request->user();
        $validated = $request->validated();

        $user->password = bcrypt($validated['password']);
        $user->save();

        return response()->json([
            'message' => 'Password updated successfully.',
        ]);

    }

      /**
 * Request Password Reset
 * 
 *
 * Allows users to request a password reset via email.
 */
      public function forgotPassword(ForgotPasswordRequest $request)
      {
          $validated = $request->validated();
          $status = Password::sendResetLink($validated);

          if ($status === Password::RESET_LINK_SENT) {
              return response()->json([
                  'message' => 'Password reset link sent to your email.',
              ]);
          } else {
              return response()->json([
                  'message' => 'Unable to send password reset link.',
              ], 500);
          }
      }

          /**
 * Password Reset
 * 
 *
 * Allows users to reset a password  via email.
 */
  public function resetPassword(ResetPasswordRequest $request)
  {
      $validated = $request->validated();
      $status = Password::reset($validated,function ($user, $password) {
              $user->password = Hash::make($password);
              $user->setRememberToken(Str::random(60));
              $user->save();

              event(new PasswordReset($user));
          }
      );

      if ($status === Password::PASSWORD_RESET) {
          return response()->json([
              'message' => 'Password has been reset successfully.',
          ]);
      } else {
          return response()->json([
              'message' => 'Failed to reset password.',
          ], 500);
      }
  }

}
