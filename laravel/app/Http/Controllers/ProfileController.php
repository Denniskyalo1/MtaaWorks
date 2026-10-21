<?php

namespace App\Http\Controllers;

use App\Http\Requests\UpdateUserRequest;
use Illuminate\Http\Request;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Validation\Rule;

/**
 * Users
 * 
 * 
 * Controller for handling user-related actions, such as registration.
 */

class ProfileController extends Controller
{
    /**
 * Retrieve User Info
 * 
 *
 * Gets the info of the currently logged in user
 */
    public function show(Request $request){
         $user = $request->user();

         return response()->json([
            'message' => 'User info retrieved successfully.',
            'user' => $user->only([
                'id',
                'name',
                'email',
                'phone_number',
                'national_id',
                'identity_verification_status',
            ])
        ]);
    }

    /**
 * Update User Info
 *
 * Updates the info of the currently logged in user
 */
 public function update(UpdateUserRequest $request)
{
    $user = $request->user();
    $validated = $request->validated();

    $user->update($validated);

    if ($user->wasChanged('email')) {
       $user->sendEmailVerificationNotification();
    }
    
    $user->refresh();

    return response()->json([
        'message' => 'User info updated successfully.',
        'user' => $user->only([
            'id',
            'name',
            'email',
            'phone_number',
            'national_id',
            'identity_verification_status',
        ]),
    ]);
}

/**
 * Complete Profile
 *
 * Lets a user who signed up with Google add the details Google doesn't provide.
 * Only works while no national ID is set.
 */
public function complete(Request $request): JsonResponse
{
    $user = $request->user();

    if (!is_null($user->national_id)) {
        return response()->json(['message' => 'Profile is already complete.'], 409);
    }

    $validated = $request->validate([
    'national_id' => [
        'required',
        'string',
        'regex:/^\d{7,8}$/',
    ],
    'phone_number' => [
        'nullable',
        'string',
        'regex:/^(?:\+254|254|0)[17]\d{8}$/',
        Rule::unique('users', 'phone_number')->ignore($user->id),
    ],
]);

    $normalizedNationalId = trim($validated['national_id']);
    $nationalIdHash = hash_hmac('sha256', $normalizedNationalId, config('app.key'));

    if (User::where('national_id_hash', $nationalIdHash)->exists()) {
        return response()->json([
            'message' => 'This national ID is already registered.',
            'errors' => ['national_id' => ['This national ID is already registered.']],
        ], 422);
    }

    $user->national_id = $normalizedNationalId;

    if (!empty($validated['phone_number'])) {
        $user->phone_number = $validated['phone_number'];
    }

    $user->save();

    return response()->json([
        'message' => 'Profile completed successfully.',
        'user' => $user->only([
            'id', 'name', 'email', 'phone_number', 'identity_verification_status',
        ]),
    ]);
}

}
