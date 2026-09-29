<?php

declare(strict_types=1);

function main(int $argc, array $argv): void
{
    $tools = allTools();

    if ($argc < 2) {
        printBanner();
        printToolList($tools);
        exit(0);
    }

    $cmd = $argv[1];

    if ($cmd === 'help' || $cmd === '--help' || $cmd === '-h') {
        if ($argc >= 3) {
            exit(printToolUsage($tools, $argv[2]));
        }
        printBanner();
        printToolList($tools);
        exit(0);
    }

    if ($cmd === 'list' || $cmd === 'ls') {
        printToolList($tools);
        exit(0);
    }

    $args = array_slice($argv, 2);

    foreach ($tools as $tool) {
        if ($tool->name() === $cmd) {
            exit($tool->run($args));
        }
    }

    echo "未知命令: {$cmd}\n\n";
    printToolList($tools);
    exit(1);
}

function printBanner(): void
{
    echo "Aotbox — 开发者常用工具箱（TypePHP AOT 原生编译）\n";
}

function printToolList(array $tools): void
{
    echo "\n用法: aotbox <工具> [参数...]\n\n工具:\n";
    foreach ($tools as $tool) {
        $name = $tool->name();
        $desc = $tool->description();
        echo "  " . $name . "\t" . $desc . "\n";
    }
    echo "\n运行 `aotbox help <工具>` 查看某工具的详细用法。\n";
}

function printToolUsage(array $tools, string $name): int
{
    foreach ($tools as $tool) {
        if ($tool->name() === $name) {
            echo $tool->usage() . "\n";
            return 0;
        }
    }
    echo "未知工具: {$name}\n";
    return 1;
}
