<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('loan_requests', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();     // the borrower
            $table->foreignId('lender_id')->constrained()->cascadeOnDelete();
            // the access grant created or reused when the borrower applied, so the lender can see the score
            $table->foreignId('score_access_grant_id')->nullable()->constrained('score_access_grants')->nullOnDelete();
            $table->decimal('amount', 12, 2);
            $table->unsignedSmallInteger('term_months');
            $table->string('purpose', 255)->nullable();
            $table->string('status', 20)->default('pending')->index();          // pending, approved, declined, withdrawn
            // CASE works in MySQL and SQLite; at most one pending request per borrower and lender
            $table->boolean('is_open')->nullable()->storedAs("CASE WHEN status = 'pending' THEN 1 ELSE NULL END");
            $table->string('decision_note', 255)->nullable();
            $table->timestamp('responded_at')->nullable();
            $table->timestamps();
            $table->unique(['user_id', 'lender_id', 'is_open']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('loan_requests');
    }
};
