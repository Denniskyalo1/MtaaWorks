<?php

namespace App\Http\Middleware;

use App\Models\User;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureRole
{
    /**
     * Handle an incoming request.
     *
     * @param  Closure(Request): (Response)  $next
     */
    public function handle(Request $request, Closure $next, string ...$roles)
    {
        $user = $request->user();

        if (! $user || ! in_array($user->role, $roles, true)) {
            return response()->json(['message' => 'Forbidden.'], 403);
        }

        // Staff of a suspended lender lose access even if they still hold a token.
        if ($user->role === User::ROLE_LENDER && ! $user->lender?->isActive()) {
            return response()->json([
                'message' => 'This lender account is suspended. Contact MtaaWorks support.',
                'code' => 'lender_suspended',
            ], 403);
        }

        return $next($request);
    }
}
