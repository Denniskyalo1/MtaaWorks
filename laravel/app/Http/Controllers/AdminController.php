<?php

namespace App\Http\Controllers;

use App\Models\AuditLog;
use App\Models\Lender;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

/**
 * Admin
 *
 * Admin-only overview, user management and audit trail.
 * The admin never sees borrowers' scores or statements: scores are
 * only shared through borrower-approved grants.
 */
class AdminController extends Controller
{
    /**
     * Dashboard
     *
     * System-wide counts. Aggregates only, no individual scores.
     */
    public function dashboard(): JsonResponse
    {
        $weekAgo = now()->subDays(7);

        $borrowers = User::where('role', User::ROLE_BORROWER);

        return response()->json([
            'users_by_role' => $this->grouped(
                User::select('role', DB::raw('count(*) as total'))->groupBy('role')
                    ->pluck('total', 'role')
            ),
            'borrowers' => [
                'total' => (clone $borrowers)->count(),
                'email_verified' => (clone $borrowers)->whereNotNull('email_verified_at')->count(),
                'phone_verified' => (clone $borrowers)->whereNotNull('phone_verified_at')->count(),
                'new_last_7_days' => (clone $borrowers)->where('created_at', '>=', $weekAgo)->count(),
            ],
            'lenders_by_status' => $this->grouped(
                Lender::select('status', DB::raw('count(*) as total'))->groupBy('status')
                    ->pluck('total', 'status')
            ),
            'scores' => [
                'total' => DB::table('credit_scores')->count(),
                'last_7_days' => DB::table('credit_scores')->where('created_at', '>=', $weekAgo)->count(),
            ],
            'grants_by_status' => $this->grouped(
                DB::table('score_access_grants')->select('status', DB::raw('count(*) as total'))
                    ->groupBy('status')->pluck('total', 'status')
            ),
            'loan_requests_by_status' => $this->grouped(
                DB::table('loan_requests')->select('status', DB::raw('count(*) as total'))
                    ->groupBy('status')->pluck('total', 'status')
            ),
            'score_views_last_7_days' => DB::table('score_access_events')
                ->where('created_at', '>=', $weekAgo)->count(),
        ]);
    }

    /**
     * List Users
     *
     * Paginated list with masked personal details. Filter by role
     * (borrower, lender, admin) and search by name or email.
     */
    public function users(Request $request): JsonResponse
    {
        $data = $request->validate([
            'role' => ['nullable', Rule::in([User::ROLE_BORROWER, User::ROLE_LENDER, User::ROLE_ADMIN])],
            'search' => 'nullable|string|max:100',
        ]);

        $query = User::with('lender:id,name')->orderByDesc('created_at');

        if (!empty($data['role'])) {
            $query->where('role', $data['role']);
        }

        if (!empty($data['search'])) {
            $term = '%' . $data['search'] . '%';
            $query->where(fn ($q) => $q->where('name', 'like', $term)->orWhere('email', 'like', $term));
        }

        $page = $query->paginate(20)->through(fn (User $user) => [
            'id' => $user->id,
            'name' => $user->name,
            'email' => $user->email,
            'role' => $user->role,
            'lender' => $user->lender?->name,
            'phone_masked' => $this->maskPhone($user->phone_number),
            'national_id_masked' => $this->maskNationalId($user),
            'email_verified' => !is_null($user->email_verified_at),
            'phone_verified' => !is_null($user->phone_verified_at),
            'created_at' => $user->created_at,
        ]);

        return response()->json($page);
    }

    /**
     * Change User Role
     *
     * Switches an account between borrower and admin. Lender staff are
     * managed through their lender (suspend the lender instead).
     */
    public function updateRole(Request $request, User $user): JsonResponse
    {
        $data = $request->validate([
            'role' => ['required', Rule::in([User::ROLE_BORROWER, User::ROLE_ADMIN])],
        ]);

        if ($user->id === $request->user()->id) {
            return response()->json(['message' => 'You cannot change your own role.'], 422);
        }

        if ($user->role === User::ROLE_LENDER) {
            return response()->json([
                'message' => 'Lender staff are managed through their lender. Suspend the lender instead.',
            ], 422);
        }

        if ($user->role === $data['role']) {
            return response()->json(['message' => "This account is already a {$data['role']}."], 409);
        }

        if ($user->role === User::ROLE_ADMIN
            && User::where('role', User::ROLE_ADMIN)->count() <= 1) {
            return response()->json(['message' => 'The last admin account cannot be removed.'], 422);
        }

        $previous = $user->role;

        DB::transaction(function () use ($request, $user, $data, $previous) {
            $user->forceFill(['role' => $data['role']])->save();

            // Old tokens carry the old role's access, so sign the user out.
            $user->tokens()->delete();

            AuditLog::record($request, 'user.role_changed', $user, [
                'email' => $user->email,
                'from' => $previous,
                'to' => $data['role'],
            ]);
        });

        return response()->json([
            'message' => "Role changed from {$previous} to {$data['role']}. The user has been signed out.",
        ]);
    }

    /**
     * Admin Audit Log
     *
     * Every admin action, newest first.
     */
    public function auditLogs(): JsonResponse
    {
        $page = AuditLog::with('actor:id,name,email')
            ->orderByDesc('created_at')
            ->orderByDesc('id')
            ->paginate(25)
            ->through(fn (AuditLog $log) => [
                'id' => $log->id,
                'action' => $log->action,
                'actor' => $log->actor?->name ?? 'Deleted user',
                'target_type' => $log->target_type,
                'target_id' => $log->target_id,
                'meta' => $log->meta,
                'ip_address' => $log->ip_address,
                'created_at' => $log->created_at,
            ]);

        return response()->json($page);
    }

    /**
     * Score Access Events
     *
     * Each time lender staff opened a borrower's score. Shows who looked,
     * not what they saw.
     */
    public function accessEvents(): JsonResponse
    {
        $page = DB::table('score_access_events as e')
            ->join('lenders as l', 'l.id', '=', 'e.lender_id')
            ->join('score_access_grants as g', 'g.id', '=', 'e.score_access_grant_id')
            ->leftJoin('users as v', 'v.id', '=', 'e.viewer_user_id')
            ->leftJoin('users as b', 'b.id', '=', 'g.user_id')
            ->select([
                'e.id',
                'e.created_at',
                'l.name as lender_name',
                'v.name as viewer_name',
                'b.name as borrower_name',
                'b.email as borrower_email',
            ])
            ->orderByDesc('e.created_at')
            ->orderByDesc('e.id')
            ->paginate(25)
            ->through(fn ($row) => [
                'id' => $row->id,
                'created_at' => $row->created_at,
                'lender' => $row->lender_name,
                'viewer' => $row->viewer_name ?? 'Deleted user',
                'borrower' => $row->borrower_name ?? 'Deleted user',
                'borrower_email_masked' => $this->maskEmail($row->borrower_email),
            ]);

        return response()->json($page);
    }

    /** Empty groups serialise as {} rather than [], so the app always gets a map. */
    private function grouped($collection): object
    {
        return (object) $collection->map(fn ($n) => (int) $n)->toArray();
    }

    private function maskPhone(?string $phone): ?string
    {
        if (empty($phone)) {
            return null;
        }

        $length = strlen($phone);

        return $length <= 5
            ? str_repeat('*', $length)
            : substr($phone, 0, 2) . str_repeat('*', $length - 5) . substr($phone, -3);
    }

    private function maskNationalId(User $user): ?string
    {
        try {
            $id = $user->national_id;
        } catch (\Throwable) {
            return 'Unreadable';
        }

        if (empty($id)) {
            return null;
        }

        return str_repeat('*', max(strlen($id) - 2, 0)) . substr($id, -2);
    }

    private function maskEmail(?string $email): ?string
    {
        if (empty($email) || !str_contains($email, '@')) {
            return $email;
        }

        [$local, $domain] = explode('@', $email, 2);

        return substr($local, 0, 1) . str_repeat('*', max(strlen($local) - 1, 1)) . '@' . $domain;
    }
}
