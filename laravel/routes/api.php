<?php

use App\Http\Controllers\AccountController;
use App\Http\Controllers\AdminLenderController;
use App\Http\Controllers\BorrowerAccessController;
use App\Http\Controllers\ConsentController;
use App\Http\Controllers\EmailVerificationController;
use App\Http\Controllers\GoogleAuthController;
use App\Http\Controllers\LenderAccessController;
use App\Http\Controllers\PasswordResetController;
use App\Http\Controllers\PhoneVerificationController;
use App\Http\Controllers\ProfileController;
use App\Http\Controllers\ScoreController;
use App\Http\Controllers\UserController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;


/*
 Route::get('/user', function (Request $request) {
   return $request->user();
  })->middleware('auth:sanctum');

  */

/**
 *
 * Routes for handling user-related actions, such as registration.
 * 
 */
Route::post('/register', [UserController::class, 'register']);
Route::post('/login', [UserController::class, 'login']);
Route::get('/email/verify/{id}/{hash}', [EmailVerificationController::class, 'verify'])->middleware(['signed', 'throttle:6,1'])->name('verification.verify');
Route::post('/forgot-password', [PasswordResetController::class, 'forgotPassword'])->name('password.email');
Route::post('/reset-password', [PasswordResetController::class, 'resetPassword'])->name('password.reset')->middleware('throttle:6,1');
Route::post('/auth/google', [GoogleAuthController::class, 'login']);

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
})->name('password.reset')->middleware('throttle:6,1');
*/



//Protected routes that require authentication
    Route::middleware(['auth:sanctum', 'role:borrower'])->group(function () {
        Route::post('/logout', [UserController::class, 'logout']);
        Route::get('/show', [ProfileController::class, 'show']);
        Route::patch('/update',[ProfileController::class, 'update']);
        Route::post('/change-password', [PasswordResetController::class, 'changePassword']);
        Route::get('/email/verification-status',[EmailVerificationController::class, 'status']);
        Route::post('/email/verification-notification',[EmailVerificationController::class, 'resend'])->middleware('throttle:6,1');
        Route::post('/profile/complete', [ProfileController::class, 'complete']);
        Route::post('/phone/send-code', [PhoneVerificationController::class, 'sendCode'])->middleware('throttle:3,1');
        Route::post('/phone/verify', [PhoneVerificationController::class, 'verify'])->middleware('throttle:5,1');
        Route::post('/account/delete/request',[AccountController::class, 'requestDeletion'])->middleware('throttle:3,1');
        Route::delete('/account',[AccountController::class, 'deleteAccount'])->middleware('throttle:5,1');
        Route::get('/consents', [ConsentController::class, 'index']);
        Route::post('/consents', [ConsentController::class, 'store'])->middleware('throttle:10,1');
        Route::delete('/consents/{purpose}', [ConsentController::class, 'destroy'])->middleware('throttle:10,1'); 
        Route::post('/scores', [ScoreController::class, 'store'])->middleware('throttle:5,1');
        Route::get('/scores', [ScoreController::class, 'index']);
        Route::get('/scores/latest', [ScoreController::class, 'latest']);
        Route::get('/access-requests', [BorrowerAccessController::class, 'index']);
        Route::post('/access-requests/{grant}/approve', [BorrowerAccessController::class, 'approve']);
        Route::post('/access-requests/{grant}/decline', [BorrowerAccessController::class, 'decline']);
        Route::post('/access-requests/{grant}/revoke', [BorrowerAccessController::class, 'revoke']);

    });

    Route::middleware(['auth:sanctum', 'role:admin', 'throttle:20,1'])->prefix('admin')->group(function () {
       Route::post('/lenders', [AdminLenderController::class, 'store']);
       Route::get('/lenders', [AdminLenderController::class, 'index']);
    });

    Route::middleware(['auth:sanctum', 'role:lender'])->prefix('lender')->group(function () {
        Route::post('/access-requests', [LenderAccessController::class, 'store'])->middleware('throttle:10,1');
        Route::get('/access-requests', [LenderAccessController::class, 'index']);
        Route::get('/grants/{grant}/score', [LenderAccessController::class, 'show']);
   });