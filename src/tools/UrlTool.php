<?php

declare(strict_types=1);

class UrlTool implements Tool
{
    public function name(): string
    {
        return 'url';
    }

    public function description(): string
    {
        return 'URL 编码 / 解码';
    }

    public function usage(): string
    {
        return "用法:\n"
            . "  aotbox url <文本>        编码\n"
            . "  aotbox url -d <文本>     解码\n"
            . "  aotbox url -r <文本>     raw 编码（RFC 3986）\n"
            . "  aotbox url -dr <文本>    raw 解码\n";
    }

    public function run(array $args): int
    {
        $decode = false;
        $raw = false;
        $text = '';

        foreach ($args as $a) {
            if ($a === '-d' || $a === '--decode') {
                $decode = true;
            } elseif ($a === '-e' || $a === '--encode') {
                $decode = false;
            } elseif ($a === '-r' || $a === '--raw') {
                $raw = true;
            } elseif ($a === '-dr' || $a === '--raw-decode') {
                $raw = true;
                $decode = true;
            } else {
                $text = $a;
            }
        }

        if ($text === '') {
            echo $this->usage();
            return 1;
        }

        if ($decode) {
            $out = $raw ? rawurldecode($text) : urldecode($text);
        } else {
            $out = $raw ? rawurlencode($text) : urlencode($text);
        }

        echo $out . "\n";
        return 0;
    }

    public function guiActions(): array
    {
        return ['编码', '解码'];
    }

    public function guiParamLabel(): string
    {
        return '';
    }

    public function guiRun(string $input, string $param, string $action): string
    {
        return $action === '解码' ? urldecode($input) : urlencode($input);
    }
}
