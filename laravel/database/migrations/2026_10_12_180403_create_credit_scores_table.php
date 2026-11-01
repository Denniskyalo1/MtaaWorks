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
        Schema::create('credit_scores', function (Blueprint $table) {
    $table->id();
    $table->foreignId('user_id')->constrained()->cascadeOnDelete();
    $table->foreignId('statement_id')->constrained()->cascadeOnDelete();
    $table->decimal('default_probability', 6, 5);
    $table->decimal('score', 5, 2);
    $table->string('risk_tier', 20);
    $table->boolean('high_risk');
    $table->json('top_drivers');
    $table->json('features');
    $table->json('imputed_features')->nullable();
    $table->json('out_of_range_features')->nullable();
    $table->string('model_version', 50);
    $table->timestamp('scored_at');
    $table->timestamps();

    $table->index(['user_id', 'scored_at']);
});
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('credit_scores');
    }
};
