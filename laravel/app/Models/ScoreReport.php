<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ScoreReport extends Model
{
    public const VALIDITY_DAYS = 30;
    // letters and digits without 0, O, 1, I so a code can be read aloud or typed from paper
    private const ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

    protected $fillable = ['user_id', 'credit_score_id', 'code', 'content_hash', 'includes_drivers', 'issued_at', 'expires_at', 'revoked_at'];

    protected $casts = [
        'includes_drivers' => 'boolean',
        'issued_at' => 'datetime',
        'expires_at' => 'datetime',
        'revoked_at' => 'datetime',
    ];

    public function user() { return $this->belongsTo(User::class); }
    public function creditScore() { return $this->belongsTo(CreditScore::class); }

    public static function newCode(): string
    {
        do {
            $groups = [];
            for ($g = 0; $g < 3; $g++) {
                $part = '';
                for ($i = 0; $i < 4; $i++) {
                    $part .= self::ALPHABET[random_int(0, strlen(self::ALPHABET) - 1)];
                }
                $groups[] = $part;
            }
            $code = 'MWR-' . implode('-', $groups);
        } while (static::where('code', $code)->exists());

        return $code;
    }

    /** Upper-case a typed code and drop spaces, so "mwr abcd-efgh-jklm" still finds its report. */
    public static function normalise(string $code): string
    {
    // Remove spaces and other separators, and standardise letter casing.
    $compact = strtoupper(preg_replace('/[^A-Z0-9]/i', '', $code) ?? '');

    // Restore the standard MWR-XXXX-XXXX-XXXX format.
    if (strlen($compact) === 15 && str_starts_with($compact, 'MWR')) {
        return substr($compact, 0, 3) . '-'
            . substr($compact, 3, 4) . '-'
            . substr($compact, 7, 4) . '-'
            . substr($compact, 11, 4);
    }

    return $compact;
    }

    /** Keyed fingerprint of what the report states. Changing the stored score changes it. */
    public function fingerprint(): string
    {
        $score = $this->creditScore;

        return hash_hmac('sha256', implode('|', [
            $this->code, $this->user_id, $score->id, $score->risk_tier, $score->score,
            $score->scored_at->toIso8601String(), $score->model_version,
        ]), (string) config('app.key'));
    }

    public static function issue(User $user, CreditScore $score, bool $includeDrivers): self
    {
        $report = new static([
            'user_id' => $user->id,
            'credit_score_id' => $score->id,
            'code' => static::newCode(),
            'content_hash' => '',
            'includes_drivers' => $includeDrivers,
            'issued_at' => now(),
            'expires_at' => now()->addDays(static::VALIDITY_DAYS),
        ]);
        $report->setRelation('creditScore', $score);
        $report->content_hash = $report->fingerprint();
        $report->save();

        return $report;
    }

    /** valid, expired, revoked or altered (the stored fingerprint no longer matches the score). */
    public function status(): string
    {
        if ($this->revoked_at) {
            return 'revoked';
        }
        if ($this->expires_at->isPast()) {
            return 'expired';
        }

        return hash_equals($this->content_hash, $this->fingerprint()) ? 'valid' : 'altered';
    }

    /** "Dennis Kyalo Kasyoki" becomes "Dennis K." so the page does not show a full name. */
    public function maskedName(): string
    {
        $parts = preg_split('/\s+/', trim((string) $this->user->name));
        $first = $parts[0] ?? '';
        $last = count($parts) > 1 ? ' ' . mb_strtoupper(mb_substr(end($parts), 0, 1)) . '.' : '';

        return $first . $last;
    }

    public function verifyUrl(): string
    {
        return rtrim((string) config('services.portal.url', 'http://localhost:5000'), '/') . '/?verify=' . $this->code;
    }

    /** The data the scoring service needs to draw the PDF. */
    public function pdfPayload(): array
    {
        $score = $this->creditScore;
        $drivers = null;

        if ($this->includes_drivers) {
            $drivers = collect((array) $score->top_drivers)->map(fn ($d) => [
                'label' => ucfirst(str_replace('_', ' ', (string) ($d['feature'] ?? ''))),
                'helping' => ((float) ($d['contribution'] ?? 0)) < 0,
            ])->values()->all();
        }

        return [
            'name' => $this->maskedName(),
            'score' => (float) $score->score,
            'tier' => $score->risk_tier,
            'high_risk' => (bool) $score->high_risk,
            'scored_at' => $score->scored_at->format('j M Y'),
            'model_version' => $score->model_version,
            'code' => $this->code,
            'hash' => substr($this->content_hash, 0, 16),
            'issued_at' => $this->issued_at->format('j M Y'),
            'valid_until' => $this->expires_at->format('j M Y'),
            'verify_url' => $this->verifyUrl(),
            'drivers' => $drivers,
        ];
    }
}
