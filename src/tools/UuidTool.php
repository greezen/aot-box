<?php

declare(strict_types=1);

class UuidTool implements Tool
{
    public function name(): string
    {
        return 'uuid';
    }

    public function description(): string
    {
        return '生成 UUID v4 / v7';
    }

    public function usage(): string
    {
        return "用法:\n"
            . "  aotbox uuid [版本] [数量]\n"
            . "  版本: 4（随机，默认）或 7（时间有序）\n"
            . "  数量: 1-100（默认 1）\n";
    }

    public function run(array $args): int
    {
        $version = 4;
        $count = 1;

        $n = count($args);
        if ($n >= 1) {
            $version = (int) $args[0];
        }
        if ($n >= 2) {
            $count = (int) $args[1];
        }

        if ($version !== 4 && $version !== 7) {
            echo "版本只支持 4 或 7\n";
            return 1;
        }
        if ($count < 1) {
            $count = 1;
        }
        if ($count > 100) {
            $count = 100;
        }

        for ($i = 0; $i < $count; $i++) {
            echo ($version === 7 ? self::uuid7() : self::uuid4()) . "\n";
        }
        return 0;
    }

    public function guiActions(): array
    {
        return ['v4', 'v7'];
    }

    public function guiParamLabel(): string
    {
        return '数量（默认 1）';
    }

    public function guiRun(string $input, string $param, string $action): string
    {
        $version = $action === 'v7' ? 7 : 4;
        $count = $param === '' ? 1 : (int) $param;
        if ($count < 1) {
            $count = 1;
        }
        if ($count > 100) {
            $count = 100;
        }
        $out = '';
        for ($i = 0; $i < $count; $i++) {
            $out .= ($version === 7 ? self::uuid7() : self::uuid4()) . "\n";
        }
        return rtrim($out, "\n");
    }

    private static function uuid4(): string
    {
        $a = random_int(0, 0xffffffff);
        $b = random_int(0, 0xffff);
        $c = random_int(0, 0xffff);
        $d = random_int(0, 0xffff);
        $e = random_int(0, 0xffffffffffff);

        return sprintf(
            '%08x-%04x-%04x-%04x-%012x',
            $a,
            0x4000 | ($b & 0x0fff),
            0x8000 | ($c & 0x3fff),
            $d,
            $e
        );
    }

    private static function uuid7(): string
    {
        $ms = (int) (microtime(true) * 1000);
        $ts = $ms & 0xffffffffffff;

        $a = $ts >> 16;
        $b = $ts & 0xffff;
        $c = random_int(0, 0xffff);
        $d = random_int(0, 0xffff);
        $e = random_int(0, 0xffffffffffff);

        return sprintf(
            '%08x-%04x-%04x-%04x-%012x',
            $a,
            $b,
            0x7000 | ($c & 0x0fff),
            0x8000 | ($d & 0x3fff),
            $e
        );
    }
}
