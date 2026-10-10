<?php

use App\Http\Controllers\PasswordResetController;
use App\Http\Controllers\ProfileController;
use App\Http\Controllers\UserController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\EmailVerificationController;

/**
 * User Routes
 * Route::get('/user', function (Request $request) {
   * return $request->user();
  *})->middleware('auth:sanctum');

 *
 * Routes for handling user-related actions, such as registration.
 * 
 */
Route::post('/register', [UserController::class, 'register']);
Route::post('/login', [UserController::class, 'login']);
Route::get('/email/verify/{id}/{hash}', [EmailVerificationController::class, 'verify'])->middleware(['signed', 'throttle:6,1'])->name('verification.verify');
Route::post('/forgot-password', [PasswordResetController::class, 'forgotPassword'])->name('password.email');
Route::post('/reset-password', [PasswordResetController::class, 'resetPassword'])->name('password.reset');

//Temporary for testing till front end is built
/*
Route::get('/reset-password/{token}', function (Request $request, $token) {
    return '
    <form action="/api/reset-password" method="POST" style="font-family: sans-serif; max-width: 400px; margin: 40px auto; padding: 20px; border: 1px solid #ccc;">
        <h2>Reset Password</h2>
        <input type="hidden" name="token" value="' . e($token) . '">
        
        <div style="margin-bottom: 15px;">
            <label>Email Address:</label><br>
            <input type="email" name="email" value="' . e($request->query('email')) . '" required style="width: 100%; padding: 8px; margin-top: 5px;">
        </div>
        
        <div style="margin-bottom: 15px;">
            <label>New Password:</label><br>
            <input type="password" name="password" required style="width: 100%; padding: 8px; margin-top: 5px;">
        </div>
        
        <div style="margin-bottom: 15px;">
            <label>Confirm Password:</label><br>
            <input type="password" name="password_confirmation" required style="width: 100%; padding: 8px; margin-top: 5px;">
        </div>
        
        <button type="submit" style="background: #007bff; color: white; padding: 10px 15px; border: none; cursor: pointer;">Update Password</button>
    </form>
    ';
})->name('password.reset');
*/


//Protected routes that require authentication
    Route::middleware('auth:sanctum')->group(function () {
        Route::post('/logout', [UserController::class, 'logout']);
        Route::get('/show', [ProfileController::class, 'show']);
        Route::patch('/update',[ProfileController::class, 'update']);
        Route::post('/change-password', [PasswordResetController::class, 'changePassword']);
        Route::get('/email/verification-status',[EmailVerificationController::class, 'status']);
        Route::post('/email/verification-notification',[EmailVerificationController::class, 'resend'])->middleware('throttle:6,1');
    });