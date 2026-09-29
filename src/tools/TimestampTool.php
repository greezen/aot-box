<?php

declare(strict_types=1);

class TimestampTool implements Tool
{
    public function name(): string
    {
        return 'time';
    }

    public function description(): string
    {
        return 'Unix 时间戳与日期互转';
    }

    public function usage(): string
    {
        return "用法:\n"
            . "  aotbox time <秒>          时间戳 → 日期（自动识别毫秒）\n"
            . "  aotbox time -t <日期>     日期 → 时间戳\n"
            . "  aotbox time now           当前时间\n";
    }

    public function run(array $args): int
    {
        $n = count($args);
        if ($n < 1) {
            echo $this->usage();
            return 1;
        }

        $first = $args[0];

        if ($first === 'now') {
            echo self::formatTimestamp(time()) . "\n";
            return 0;
        }

        if ($first === '-t' || $first === '--to-ts') {
            if ($n < 2) {
                echo $this->usage();
                return 1;
            }
            $ts = strtotime($args[1]);
            if ($ts === false) {
                echo "无法解析日期: {$args[1]}\n";
                return 1;
            }
            echo "秒:   " . $ts . "\n"
                . "毫秒: " . ($ts * 1000) . "\n"
                . "ISO:  " . gmdate('c', $ts) . "\n";
            return 0;
        }

        if (!ctype_digit($first)) {
            echo "请输入纯数字时间戳\n";
            return 1;
        }

        $ts = (int) $first;
        if ($ts > 1000000000000) {
            $ts = intdiv($ts, 1000);
        }

        echo self::formatTimestamp($ts) . "\n";
        return 0;
    }

    public function guiActions(): array
    {
        return ['时间戳→日期', '日期→时间戳', '当前时间'];
    }

    public function guiParamLabel(): string
    {
        return '';
    }

    public function guiRun(string $input, string $param, string $action): string
    {
        if ($action === '当前时间') {
            return self::formatTimestamp(time());
        }
        if ($action === '日期→时间戳') {
            $ts = strtotime($input);
            if ($ts === false) {
                return '无法解析日期: ' . $input;
            }
            return "秒: " . $ts . "\n毫秒: " . ($ts * 1000) . "\nISO: " . gmdate('c', $ts);
        }
        if (!ctype_digit($input)) {
            return '请输入纯数字时间戳';
        }
        $ts = (int) $input;
        if ($ts > 1000000000000) {
            $ts = intdiv($ts, 1000);
        }
        return self::formatTimestamp($ts);
    }

    private static function formatTimestamp(int $ts): string
    {
        return "UTC:  " . gmdate('Y-m-d H:i:s', $ts) . "\n"
            . "本地: " . date('Y-m-d H:i:s', $ts) . "\n"
            . "ISO:  " . gmdate('c', $ts) . "\n"
            . "秒:   " . $ts . "\n"
            . "毫秒: " . ($ts * 1000);
    }
}
