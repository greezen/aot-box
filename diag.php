<?php

declare(strict_types=1);

function main(): void
{
    ui_app_init('diag');
    ui_create_window('diag', 500, 400);
    $input = ui_add_text_view('{"a":1}', 20, 200, 400, 150);
    $output = ui_add_text_view('', 20, 20, 400, 150);

    echo "step1: reading input\n";
    $text = ui_get_control_text($input);
    echo "step1 ok: [" . $text . "]\n";

    echo "step2: json decode/encode\n";
    $data = json_decode($text);
    $result = json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    echo "step2 ok: [" . $result . "]\n";

    echo "step3: setting output\n";
    ui_set_control_text($output, $result);
    echo "step3 ok\n";

    echo "ALL DONE\n";
}
