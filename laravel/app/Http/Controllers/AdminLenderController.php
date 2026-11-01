<?php

namespace App\Http\Controllers;

use App\Models\Lender;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Password;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;


/**
 * Admin: Lenders
 *
 * Admin-only management of lender organisations.
 */
class AdminLenderController extends Controller
{
      /** Create Lender: creates a lender organisation and its first staff account, then emails a set-password link. */
    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name'           => 'required|string|max:255|unique:lenders,name',
            'type'           => ['required', Rule::in(Lender::TYPES)],
            'licence_number' => 'required|string|max:100|unique:lenders,licence_number',
            'contact_name'   => 'required|string|max:255',
            'contact_email'  => 'required|email|max:255|unique:users,email',
        ]);

        $user = DB::transaction(function () use ($data, $request) {
            $lender = Lender::create([
                'name' => $data['name'],
                'type' => $data['type'],
                'licence_number' => $data['licence_number'],
                'created_by' => $request->user()->id,
            ]);

            $user = new User();
            $user->forceFill([
                'name' => $data['contact_name'],
                'email' => $data['contact_email'],
                'password' => Hash::make(Str::random(40)),
                'role' => User::ROLE_LENDER,
                'lender_id' => $lender->id,
                'email_verified_at' => now(),
            ])->save();

            return $user;
        });

        Password::sendResetLink(['email' => $user->email]);

        return response()->json([
            'message' => 'Lender created. A set-password link was emailed to the contact.',
            'lender' => $user->lender->only(['id', 'name', 'type', 'status']),
        ], 201);
    }

     /** List Lenders */
    public function index(): JsonResponse
    {
        return response()->json(['lenders' => Lender::orderBy('name')->get(['id', 'name', 'type', 'status'])]);
    }

    
}
