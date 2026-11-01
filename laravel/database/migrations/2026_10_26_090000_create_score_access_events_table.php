<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // One row each time lender staff open a borrower's score, so the borrower can see who looked at it
        Schema::create('score_access_events', function (Blueprint $table) {
            $table->id();
            $table->foreignId('score_access_grant_id')->constrained('score_access_grants')->cascadeOnDelete();
            $table->foreignId('lender_id')->constrained()->cascadeOnDelete();
            $table->foreignId('viewer_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('event', 20)->default('viewed');
            $table->string('scope', 30);
            $table->timestamp('created_at')->useCurrent();
            $table->index(['score_access_grant_id', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('score_access_events');
    }
};
