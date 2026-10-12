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
        Schema::table('users', function (Blueprint $table) {
    $table->string('role', 20)->default('borrower')->index()->after('email');
    $table->foreignId('lender_id')->nullable()->after('role')->constrained('lenders')->restrictOnDelete();
});
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            Schema::dropifExists('role');
            Schema::dropifExists(['lender_id']);
            Schema::dropIfExists('lender_id');
        });
    }
};
