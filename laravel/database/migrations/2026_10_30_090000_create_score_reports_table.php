<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('score_reports', function (Blueprint $table) {
            $table->id();

            $table->foreignId('user_id')
                ->constrained()
                ->cascadeOnDelete();

            $table->foreignId('credit_score_id')
                ->constrained('credit_scores')
                ->cascadeOnDelete();

            $table->string('code', 20)->unique();
            $table->string('content_hash', 64);
            $table->boolean('includes_drivers')->default(false);

            $table->timestamp('issued_at')->useCurrent();
            $table->dateTime('expires_at');
            $table->timestamp('revoked_at')->nullable();

            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('score_reports');
    }
};