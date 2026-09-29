<?php

declare(strict_types=1);

/**
 * Native macOS GUI for the toolbox.
 *
 * Owns the window layout, application state and click behavior. AppKit owns
 * the actual controls; the Objective-C++ bridge (objc-src/) exposes only the
 * small set of `ui_*` operations used here.
 */
final class GuiApp
{
    private static array $tools = [];
    private static array $sidebarIds = [];
    private static int $currentIndex = 0;

    private static array $actionIds = [0, 0, 0, 0];
    private static int $titleId = 0;
    private static int $descId = 0;
    private static int $inputId = 0;
    private static int $paramCaptionId = 0;
    private static int $paramId = 0;
    private static int $outputId = 0;

    public static function build(): void
    {
        self::$tools = allTools();

        ui_create_window('Aotbox', 920, 640);

        // Sidebar: one button per tool, top to bottom.
        $count = count(self::$tools);
        for ($i = 0; $i < $count; $i++) {
            $tool = self::$tools[$i];
            $y = 596 - $i * 44;
            self::$sidebarIds[$i] = ui_add_button($tool->name(), 16, $y, 188, 36, 0);
        }

        // Content area.
        self::$titleId = ui_add_label('', 224, 600, 680, 26, 18, true);
        self::$descId = ui_add_label('', 224, 576, 680, 18, 12, false);

        ui_add_label('输入', 224, 550, 100, 16, 12, false);
        self::$inputId = ui_add_text_view('', 224, 356, 680, 190);

        self::$paramCaptionId = ui_add_label('', 224, 330, 680, 16, 12, false);
        self::$paramId = ui_add_text_field('', 224, 302, 680, 24);

        ui_add_label('输出', 224, 232, 100, 16, 12, false);
        self::$outputId = ui_add_text_view('', 224, 16, 680, 212);
        ui_set_control_editable(self::$outputId, false);

        for ($i = 0; $i < 4; $i++) {
            self::$actionIds[$i] = ui_add_button('', 224 + $i * 140, 258, 132, 32, 0);
        }

        self::selectTool(0);
    }

    public static function handleEvent(int $controlId): void
    {
        $n = count(self::$sidebarIds);
        for ($i = 0; $i < $n; $i++) {
            if (self::$sidebarIds[$i] === $controlId) {
                self::selectTool($i);
                return;
            }
        }

        for ($i = 0; $i < 4; $i++) {
            if (self::$actionIds[$i] === $controlId) {
                self::runAction($i);
                return;
            }
        }
    }

    private static function selectTool(int $index): void
    {
        self::$currentIndex = $index;
        $tool = self::$tools[$index];

        ui_set_control_text(self::$titleId, $tool->name());
        ui_set_control_text(self::$descId, $tool->description());

        $actions = $tool->guiActions();
        $n = count($actions);
        for ($i = 0; $i < 4; $i++) {
            $visible = $i < $n;
            ui_set_control_visible(self::$actionIds[$i], $visible);
            if ($visible) {
                ui_set_control_text(self::$actionIds[$i], $actions[$i]);
            }
        }

        $paramLabel = $tool->guiParamLabel();
        $hasParam = $paramLabel !== '';
        ui_set_control_visible(self::$paramCaptionId, $hasParam);
        ui_set_control_visible(self::$paramId, $hasParam);
        if ($hasParam) {
            ui_set_control_text(self::$paramCaptionId, $paramLabel);
            ui_set_control_text(self::$paramId, '');
        }

        ui_set_control_text(self::$outputId, '');
    }

    private static function runAction(int $actionIndex): void
    {
        $tool = self::$tools[self::$currentIndex];
        $actions = $tool->guiActions();
        if ($actionIndex >= count($actions)) {
            return;
        }

        $input = ui_get_control_text(self::$inputId);
        $param = ui_get_control_text(self::$paramId);
        $result = $tool->guiRun($input, $param, $actions[$actionIndex]);
        ui_set_control_text(self::$outputId, $result);
    }
}
