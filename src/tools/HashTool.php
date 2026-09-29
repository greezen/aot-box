<?php

declare(strict_types=1);

class HashTool implements Tool
{
    public function name(): string
    {
        return 'hash';
    }

    public function description(): string
    {
        return '计算 MD5 / SHA 系列哈希';
    }

    public function usage(): string
    {
        return "用法:\n"
            . "  aotbox hash <算法> <文本>\n"
            . "  算法: md5, sha1, sha224, sha256, sha384, sha512（默认 sha256）\n"
            . "  aotbox hash <文本>\n";
    }

    public function run(array $args): int
    {
        $n = count($args);
        if ($n < 1) {
            echo $this->usage();
            return 1;
        }

        $algo = 'sha256';
        $text = '';

        if ($n >= 2) {
            $algo = strtolower($args[0]);
            $text = $args[1];
        } else {
            $text = $args[0];
        }

        if (!in_array($algo, ['md5', 'sha1', 'sha224', 'sha256', 'sha384', 'sha512'], true)) {
            echo "不支持的算法: {$algo}\n";
            echo $this->usage();
            return 1;
        }

        echo hash($algo, $text) . "\n";
        return 0;
    }

    public function guiActions(): array
    {
        return ['计算'];
    }

    public function guiParamLabel(): string
    {
        return '算法（默认 sha256）';
    }

    public function guiRun(string $input, string $param, string $action): string
    {
        $algo = $param === '' ? 'sha256' : strtolower($param);
        if (!in_array($algo, ['md5', 'sha1', 'sha224', 'sha256', 'sha384', 'sha512'], true)) {
            return '不支持的算法: ' . $algo;
        }
        return hash($algo, $input);
    }
}
