<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Mail\OtpVerificationMail;
use App\Models\EmailVerificationCode;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Exceptions\HttpResponseException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;

/**
 * Email OTP registration — mirror of Node /api/email-auth/* behaviour.
 */
class EmailAuthController extends Controller
{
    private const OTP_TTL_MINUTES = 10;

    private const RESEND_SECONDS = 60;

    public function register(Request $request): JsonResponse
    {
        $data = $request->validate([
            'full_name' => 'sometimes|string|min:2|max:255',
            'fullName' => 'sometimes|string|min:2|max:255',
            'email' => 'required|email|max:320',
            'password' => [
                'required',
                'string',
                'min:8',
                'regex:/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).+$/',
            ],
        ]);
        $fullName = trim((string) ($data['full_name'] ?? $data['fullName'] ?? ''));
        if ($fullName === '') {
            return \response()->json([
                'error' => 'fullName or full_name is required',
            ], 422);
        }
        unset($data['full_name'], $data['fullName']);
        $data['full_name'] = $fullName;

        if (User::query()->where('email', $data['email'])->exists()) {
            return \response()->json(['error' => 'Email already registered'], 409);
        }

        $user = User::create([
            'name' => $data['full_name'],
            'email' => $data['email'],
            'password' => Hash::make($data['password']),
            'is_verified' => false,
        ]);

        $plain = $this->issueOtpOrThrow($data['email']);
        $sent = $this->sendOtpMailable($data['email'], $plain);

        return \response()->json([
            'ok' => true,
            'userId' => (string) $user->getKey(),
            'email' => $user->email,
            'role' => 'patient',
            'verificationSentTo' => $user->email,
            'emailActuallySent' => $sent,
            'message' => $sent
                ? 'Verification code sent to your email'
                : 'Could not send email. Check MAIL_* in .env and the Laravel log.',
        ], 201);
    }

    public function verifyEmail(Request $request): JsonResponse
    {
        $data = $request->validate([
            'email' => 'required|email',
            'code' => 'required|string|size:6',
        ]);

        $rows = EmailVerificationCode::query()
            ->where('email', $data['email'])
            ->whereNull('used_at')
            ->where('expires_at', '>', Carbon::now())
            ->orderByDesc('id')
            ->limit(5)
            ->get();

        foreach ($rows as $row) {
            if (Hash::check($data['code'], $row->otp_hash)) {
                $row->used_at = Carbon::now();
                $row->save();

                $user = User::query()->where('email', $data['email'])->firstOrFail();
                $user->is_verified = true;
                $user->save();

                return \response()->json([
                    'ok' => true,
                    'verified' => true,
                    'message' => 'Email verified successfully',
                    'user' => [
                        'userId' => (string) $user->getKey(),
                        'fullName' => $user->name,
                        'email' => $user->email,
                        'role' => 'patient',
                    ],
                ]);
            }
        }

        return \response()->json(['error' => 'Invalid or expired verification code'], 400);
    }

    public function resendCode(Request $request): JsonResponse
    {
        $data = $request->validate([
            'email' => 'required|email',
        ]);

        $user = User::query()->where('email', $data['email'])->first();
        if (! $user) {
            return \response()->json(['error' => 'No registration found for this email'], 404);
        }
        if ($user->is_verified) {
            return \response()->json(['error' => 'This email is already verified'], 400);
        }

        $plain = $this->issueOtpOrThrow($data['email']);
        $sent = $this->sendOtpMailable($data['email'], $plain);

        return \response()->json([
            'ok' => true,
            'email' => $user->email,
            'verificationSentTo' => $user->email,
            'emailActuallySent' => $sent,
            'message' => $sent
                ? 'A new verification code was sent to your email'
                : 'Could not send email. Check MAIL_* in .env and the Laravel log.',
        ]);
    }

    private function issueOtpOrThrow(string $email): string
    {
        $last = EmailVerificationCode::query()
            ->where('email', $email)
            ->orderByDesc('id')
            ->first();

        if ($last) {
            $since = time() - $last->created_at->getTimestamp();
            if ($since >= 0 && $since < self::RESEND_SECONDS) {
                $wait = self::RESEND_SECONDS - $since;
                throw new HttpResponseException(
                    \response()->json([
                        'error' => "Please wait {$wait} seconds before requesting a new code",
                        'retryAfterSeconds' => $wait,
                    ], 429)
                );
            }
        }

        $plain = (string) random_int(100000, 999999);
        $row = new EmailVerificationCode();
        $row->email = $email;
        $row->otp_hash = Hash::make($plain);
        $row->expires_at = Carbon::now()->addMinutes(self::OTP_TTL_MINUTES);
        $row->created_at = Carbon::now();
        $row->save();

        return $plain;
    }

    /**
     * Sends OTP via Illuminate Mail + OtpVerificationMail. Never exposes the code in JSON.
     *
     * @return bool True if mail accepted by the transport; false in non-production on failure.
     */
    private function sendOtpMailable(string $to, string $code): bool
    {
        try {
            Mail::to($to)->send(new OtpVerificationMail($code));

            return true;
        } catch (\Throwable $e) {
            Log::error('EmailAuthController: OTP mail failed', [
                'to' => $to,
                'error' => $e->getMessage(),
            ]);
            if (\app()->environment('production')) {
                throw $e;
            }

            return false;
        }
    }
}
