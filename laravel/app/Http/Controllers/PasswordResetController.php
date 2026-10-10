<?php

namespace App\Http\Controllers;

use App\Http\Requests\UpdatePasswordRequest;

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
}
