<?php

declare(strict_types=1);

function main(): void
{
    ui_app_init('Aotbox');
    GuiApp::build();
    ui_show_window();
    while (true) {
        $controlId = ui_next_event();
        if ($controlId < 0) {
            break;
        }
        GuiApp::handleEvent($controlId);
    }
}
