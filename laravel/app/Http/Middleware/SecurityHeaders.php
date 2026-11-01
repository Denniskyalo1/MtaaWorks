<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class SecurityHeaders
{
    public function handle(Request $request, Closure $next): Response
    {
        $response = $next($request);

if ($request->is('api/*')) {
    $response->headers->set('X-Content-Type-Options', 'nosniff');
    $response->headers->set('X-Frame-Options', 'DENY');
    $response->headers->set('Content-Security-Policy', "default-src 'none'; frame-ancestors 'none'");
    $response->headers->set('Referrer-Policy', 'no-referrer');
}

$response->headers->remove('X-Powered-By');
header_remove('X-Powered-By');

return $response;
    }
}