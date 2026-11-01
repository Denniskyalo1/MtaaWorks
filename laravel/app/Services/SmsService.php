<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class SmsService
{
    public function send(string $to, string $message): bool
    {
        $cfg = config('services.africastalking');

        $url = $cfg['sandbox']
            ? 'https://api.sandbox.africastalking.com/version1/messaging'
            : 'https://api.africastalking.com/version1/messaging';

        $payload = [
            'username' => $cfg['username'],
            'to'       => $to,
            'message'  => $message,
        ];

        if (!empty($cfg['sender_id'])) {
            $payload['from'] = $cfg['sender_id'];
        }

        try {
            $response = Http::withHeaders([
                    'apiKey' => $cfg['api_key'],
                    'Accept' => 'application/json',
                ])
                ->asForm()
                ->timeout(15)
                ->post($url, $payload);
        } catch (\Throwable $e) {
            Log::error('SMS request failed: ' . $e->getMessage());
            return false;
        }

        $status = strtolower($response->json('SMSMessageData.Recipients.0.status') ?? '');

        if (!$response->successful() || $status !== 'success') {
            Log::error('SMS not sent. HTTP ' . $response->status());
            return false;
        }

        return true;
    }
}