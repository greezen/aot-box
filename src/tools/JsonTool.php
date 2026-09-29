<?php

declare(strict_types=1);

class JsonTool implements Tool
{
    public function name(): string
    {
        return 'json';
    }

    public function description(): string
    {
        return 'JSON 格式化 / 压缩 / 校验';
    }

    public function usage(): string
    {
        return "用法:\n"
            . "  aotbox json <json>       格式化（4 空格缩进）\n"
            . "  aotbox json -c <json>    压缩为单行\n"
            . "  aotbox json -v <json>    校验合法性\n";
    }

    public function run(array $args): int
    {
        $mode = 'pretty';
        $text = '';

        $n = count($args);
        if ($n >= 1) {
            $first = $args[0];
            if ($first === '-c' || $first === '--compact') {
                $mode = 'compact';
                $text = $n >= 2 ? $args[1] : '';
            } elseif ($first === '-v' || $first === '--validate') {
                $mode = 'validate';
                $text = $n >= 2 ? $args[1] : '';
            } else {
                $text = $first;
            }
        }

        if ($text === '') {
            echo $this->usage();
            return 1;
        }

        $data = json_decode($text);
        if (json_last_error() !== JSON_ERROR_NONE) {
            echo "JSON 解析失败: " . json_last_error_msg() . "\n";
            return 1;
        }

        if ($mode === 'validate') {
            echo "合法 JSON ✓\n";
            return 0;
        }

        if ($mode === 'compact') {
            echo json_encode($data) . "\n";
            return 0;
        }

        echo json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES) . "\n";
        return 0;
    }

    public function guiActions(): array
    {
        return ['格式化', '压缩', '校验'];
    }

    public function guiParamLabel(): string
    {
        return '';
    }

    public function guiRun(string $input, string $param, string $action): string
    {
        $data = json_decode($input);
        if (json_last_error() !== JSON_ERROR_NONE) {
            return 'JSON 解析失败: ' . json_last_error_msg();
        }
        if ($action === '校验') {
            return '✓ 合法 JSON';
        }
        if ($action === '压缩') {
            return json_encode($data);
        }
        return json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    }
}
