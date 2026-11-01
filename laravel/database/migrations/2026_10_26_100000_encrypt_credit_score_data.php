<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Encrypts the stored scores and their behavioural detail. Back up the database before running it:
 * existing rows are rewritten, and they can only be read with the same APP_KEY afterwards.
 */
return new class extends Migration
{
    private array $json = ['top_drivers', 'features', 'imputed_features', 'out_of_range_features'];
    private array $numbers = ['default_probability', 'score'];

    public function up(): void
    {
        Schema::table('credit_scores', function (Blueprint $table) {
            $table->text('default_probability')->change();
            $table->text('score')->change();
            $table->longText('top_drivers')->change();
            $table->longText('features')->change();
            $table->longText('imputed_features')->nullable()->change();
            $table->longText('out_of_range_features')->nullable()->change();
        });

        DB::table('credit_scores')->orderBy('id')->chunkById(200, function ($rows) {
            foreach ($rows as $row) {
                $update = [];
                foreach (array_merge($this->numbers, $this->json) as $column) {
                    if ($row->$column !== null) {
                        $update[$column] = Crypt::encryptString((string) $row->$column);
                    }
                }
                DB::table('credit_scores')->where('id', $row->id)->update($update);
            }
        });
    }

    public function down(): void
    {
        DB::table('credit_scores')->orderBy('id')->chunkById(200, function ($rows) {
            foreach ($rows as $row) {
                $update = [];
                foreach (array_merge($this->numbers, $this->json) as $column) {
                    if ($row->$column !== null) {
                        $update[$column] = Crypt::decryptString($row->$column);
                    }
                }
                DB::table('credit_scores')->where('id', $row->id)->update($update);
            }
        });

        Schema::table('credit_scores', function (Blueprint $table) {
            $table->decimal('default_probability', 6, 5)->change();
            $table->decimal('score', 5, 2)->change();
            $table->json('top_drivers')->change();
            $table->json('features')->change();
            $table->json('imputed_features')->nullable()->change();
            $table->json('out_of_range_features')->nullable()->change();
        });
    }
};
