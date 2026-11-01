<?php

namespace App\Http\Controllers;

use App\Http\Requests\UpdateUserRequest;
use Illuminate\Http\Request;

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

}
