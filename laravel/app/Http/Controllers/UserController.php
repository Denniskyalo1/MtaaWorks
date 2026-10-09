<?php

namespace App\Http\Controllers;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;


/**
 * Users
 * 
 * 
 * Controller for handling user-related actions, such as registration.
 */


class UserController extends Controller
{
/**
 * Register
 * 
 *
 * Allows users to register.
 */
    public function register(Request $request){
       $validated = $request->validate([
        'name' => 'required|string|max:255',
        'email' => 'required|string|email|max:255|unique:users',
        'phone_number' => 'nullable|string|max:20|unique:users',
        'national_id' => 'required|string|max:255|unique:users',
        'password' => 'required|string|min:8|confirmed',
       ]);
       
      $normalizedNationalId = trim($validated['national_id']);
      $nationalIdHash = hash('sha256', $normalizedNationalId);

      if (User::where('national_id_hash', $nationalIdHash)->exists()) {
            return response()->json([
                'message' => 'This national ID is already registered.',
                'errors' => [
                    'national_id' => [
                        'This national ID is already registered.',
                    ],
                ],
            ], 422);
        }

       $user = User::create([
            'name' => $validated['name'],
            'email' => $validated['email'],
            'phone_number' => $validated['phone_number'] ?? null,
            'national_id' => $normalizedNationalId,
            'national_id_hash' => $nationalIdHash,
            'password' => Hash::make($validated['password']),
        ]);

          return response()->json([
            'message' => 'Registration successful.',
            'user' => [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
                'phone_number' => $user->phone_number,
                'identity_verification_status' => $user->identity_verification_status,
                'created_at' => $user->created_at,
            ],
        ], 201);
    }

    /**
 * Login
 * 
 *
 * Allows users to login.
 */

    public function login(Request $request){
        $validated = $request->validate([
            'email' => 'required|string|email',
            'password' => 'required|string',
        ]);

        $user = User::where('email', $validated['email'])->first();

        if (!$user || !Hash::check($validated['password'], $user->password)) {
            return response()->json([
                'message' => 'Invalid credentials.',
            ], 401);
        }

        // Generate a token for the user
        $token = $user->createToken('auth_token')->plainTextToken;

        return response()->json([
            'message' => 'Login successful.',
            'access_token' => $token,
            'token_type' => 'Bearer',
        ]);
    }
   /**
 * Logout
 * 
 *
 * Allows users to logout.
 */
    public function logout(Request $request)
{
    // Double-check if the user instance exists
    if ($request->user()) {
        // Revoke the specific token used for this request
        $request->user()->currentAccessToken()->delete();

        return response()->json([
            'message' => 'Logout successful.',
        ]);
    }

    return response()->json([
        'message' => 'Unauthenticated or no active session.',
    ], 401);
}

}
