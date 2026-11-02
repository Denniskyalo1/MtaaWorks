<?php

namespace App\Http\Controllers;

use App\Models\AuditLog;
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

        [$lender, $user] = DB::transaction(function () use ($data, $request) {
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

            AuditLog::record($request, 'lender.created', $lender, [
                'name' => $lender->name,
                'type' => $lender->type,
                'contact_email' => $user->email,
            ]);

            return [$lender, $user];
        });

        Password::sendResetLink(['email' => $user->email]);

        return response()->json([
            'message' => 'Lender created. A set-password link was emailed to the contact.',
            'lender' => $lender->fresh()->only(['id', 'name', 'type', 'status']),
        ], 201);
    }

     /** List Lenders */
    public function index(): JsonResponse
    {
        $lenders = Lender::withCount('staff')
            ->orderBy('name')
            ->get(['id', 'name', 'type', 'licence_number', 'status', 'created_at']);

        return response()->json(['lenders' => $lenders]);
    }

    /**
     * Suspend or Reactivate Lender
     *
     * Suspending blocks the lender's staff from the portal and signs them out.
     * Their data and grants are kept, so reactivating restores access.
     */
    public function updateStatus(Request $request, Lender $lender): JsonResponse
    {
        $data = $request->validate([
            'status' => ['required', Rule::in([Lender::STATUS_ACTIVE, Lender::STATUS_SUSPENDED])],
            'reason' => 'nullable|string|max:500',
        ]);

        if ($lender->status === $data['status']) {
            return response()->json([
                'message' => "This lender is already {$data['status']}.",
            ], 409);
        }

        DB::transaction(function () use ($request, $lender, $data) {
            $previous = $lender->status;

            $lender->status = $data['status'];
            $lender->save();

            if ($data['status'] === Lender::STATUS_SUSPENDED) {
                // Sign out every staff member straight away.
                $lender->staff()->each(fn (User $staff) => $staff->tokens()->delete());
            }

            AuditLog::record(
                $request,
                $data['status'] === Lender::STATUS_SUSPENDED ? 'lender.suspended' : 'lender.reactivated',
                $lender,
                array_filter([
                    'name' => $lender->name,
                    'from' => $previous,
                    'to' => $data['status'],
                    'reason' => $data['reason'] ?? null,
                ])
            );
        });

        return response()->json([
            'message' => $data['status'] === Lender::STATUS_SUSPENDED
                ? 'Lender suspended. Its staff have been signed out.'
                : 'Lender reactivated.',
            'lender' => $lender->only(['id', 'name', 'type', 'status']),
        ]);
    }
}
