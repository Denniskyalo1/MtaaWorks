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
        Schema::create('consents', function (Blueprint $table) {
    $table->id();
    $table->foreignId('user_id')->constrained()->cascadeOnDelete();
    $table->string('purpose', 50);
    $table->string('policy_version', 20);
    $table->timestamp('granted_at');
    $table->timestamp('revoked_at')->nullable();
    $table->boolean('is_active')->nullable()->storedAs('IF(revoked_at IS NULL, 1, NULL)');
    $table->timestamps();

    $table->unique(['user_id', 'purpose', 'is_active']);
});
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('consents');
    }
};
