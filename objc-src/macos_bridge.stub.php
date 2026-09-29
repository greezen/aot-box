<?php

declare(strict_types=1);

/** Thin wrappers around the macOS AppKit API, implemented in macos_bridge.mm. */

function ui_app_init(string $applicationName): void {}

function ui_create_window(string $title, int $width, int $height): void {}

function ui_add_label(
    string $text,
    int $x,
    int $y,
    int $width,
    int $height,
    int $fontSize,
    bool $bold
): int {}

function ui_add_button(string $title, int $x, int $y, int $width, int $height, int $style): int {}

function ui_add_text_field(string $text, int $x, int $y, int $width, int $height): int {}

function ui_add_text_view(string $text, int $x, int $y, int $width, int $height): int {}

function ui_set_control_text(int $controlId, string $text): void {}

function ui_get_control_text(int $controlId): string {}

function ui_set_control_editable(int $controlId, bool $editable): void {}

function ui_set_control_visible(int $controlId, bool $visible): void {}

function ui_show_window(): void {}

/** Return the activated control ID, or -1 after the window is closed. */
function ui_next_event(): int {}
