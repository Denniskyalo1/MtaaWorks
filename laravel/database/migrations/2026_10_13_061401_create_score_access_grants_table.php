<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
          Schema::create('score_access_grants', function (Blueprint $table) {
    $table->id();
    $table->foreignId('lender_id')->constrained()->cascadeOnDelete();
    $table->foreignId('user_id')->constrained()->cascadeOnDelete();   // the borrower
    $table->foreignId('requested_by')->nullable()->constrained('users')->nullOnDelete();
    $table->foreignId('credit_score_id')->nullable()->constrained()->nullOnDelete();
    $table->string('scope', 30)->default('score_tier');
    $table->string('status', 20)->default('requested')->index();
    $table->boolean('is_open')->nullable()->storedAs("IF(status IN ('requested','approved'), 1, NULL)");
    $table->timestamp('requested_at');
    $table->timestamp('responded_at')->nullable();
    $table->timestamp('expires_at')->nullable();
    $table->timestamp('revoked_at')->nullable();
    $table->timestamp('last_viewed_at')->nullable();
    $table->unsignedInteger('view_count')->default(0);
    $table->timestamps();

    $table->unique(['lender_id', 'user_id', 'is_open']);
});
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('score_access_grants');
    }
};
