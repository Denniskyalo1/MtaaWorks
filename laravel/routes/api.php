<?php

use App\Http\Controllers\PasswordResetController;
use App\Http\Controllers\ProfileController;
use App\Http\Controllers\UserController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

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

//Protected routes that require authentication
    Route::middleware('auth:sanctum')->group(function () {
        Route::post('/logout', [UserController::class, 'logout']);
        Route::get('/show', [ProfileController::class, 'show']);
        Route::patch('/update',[ProfileController::class, 'update']);
        Route::post('/change-password', [PasswordResetController::class, 'changePassword']);
    });