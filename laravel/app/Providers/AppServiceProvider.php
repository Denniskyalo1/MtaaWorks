<?php

namespace App\Providers;

use App\Models\User;
use Illuminate\Auth\Notifications\ResetPassword;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\ServiceProvider;
use Illuminate\Support\Facades\URL;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        Model::preventSilentlyDiscardingAttributes(! app()->isProduction());
        URL::forceRootUrl(config('app.url'));

        // Lender staff set and reset their password in the lender portal, so their emailed link points
        // there. Everyone else keeps Laravel's default link.
        ResetPassword::createUrlUsing(function ($notifiable, string $token) {
            $email = $notifiable->getEmailForPasswordReset();

            if (($notifiable->role ?? null) === User::ROLE_LENDER) {
                return rtrim((string) config('services.portal.url', 'http://localhost:5000'), '/')
                    . '/?' . http_build_query(['token' => $token, 'email' => $email]);
            }

            return url(route('password.reset', ['token' => $token, 'email' => $email], false));
        });
    }
}
