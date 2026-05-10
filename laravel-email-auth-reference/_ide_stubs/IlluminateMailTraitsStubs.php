<?php

declare(strict_types=1);

namespace Illuminate\Bus;

trait Queueable
{
}

namespace Illuminate\Queue;

trait SerializesModels
{
}

namespace Illuminate\Mail\Mailables;

class Envelope
{
    public function __construct(
        public string $subject = '',
    ) {}
}

class Content
{
    /**
     * @param  array<string, mixed>  $with
     */
    public function __construct(
        public string $html = '',
        public string $text = '',
        public array $with = [],
    ) {}
}

namespace Illuminate\Mail;

abstract class Mailable
{
}

class PendingMail
{
    public function send(Mailable $mailable): void {}
}
