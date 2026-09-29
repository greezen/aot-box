<?php

declare(strict_types=1);

class Base64Tool implements Tool
{
    public function name(): string
    {
        return 'base64';
    }

    public function description(): string
    {
        return 'Base64 编码 / 解码';
    }

    public function usage(): string
    {
        return "用法:\n"
            . "  aotbox base64 <文本>        编码\n"
            . "  aotbox base64 -d <base64>   解码\n"
            . "  aotbox base64 -u <文本>     URL 安全编码（- _ 无填充）\n"
            . "  aotbox base64 -du <base64>  URL 安全解码\n";
    }

    public function run(array $args): int
    {
        $decode = false;
        $url = false;
        $text = '';

        foreach ($args as $a) {
            if ($a === '-d' || $a === '--decode') {
                $decode = true;
            } elseif ($a === '-e' || $a === '--encode') {
                $decode = false;
            } elseif ($a === '-u' || $a === '--url') {
                $url = true;
            } elseif ($a === '-du' || $a === '--url-decode') {
                $url = true;
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
            $out = $url ? self::b64urlDecode($text) : base64_decode($text, true);
            if ($out === false) {
                echo "非法 Base64 输入\n";
                return 1;
            }
        } else {
            $out = $url ? self::b64urlEncode($text) : base64_encode($text);
        }

        echo $out . "\n";
        return 0;
    }

    public function guiActions(): array
    {
        return ['编码', '解码', 'URL编码', 'URL解码'];
    }

    public function guiParamLabel(): string
    {
        return '';
    }

    public function guiRun(string $input, string $param, string $action): string
    {
        $decode = $action === '解码' || $action === 'URL解码';
        $url = $action === 'URL编码' || $action === 'URL解码';
        if ($decode) {
            $out = $url ? self::b64urlDecode($input) : base64_decode($input, true);
            if ($out === false) {
                return '非法 Base64 输入';
            }
        } else {
            $out = $url ? self::b64urlEncode($input) : base64_encode($input);
        }
        return $out;
    }

    private static function b64urlEncode(string $s): string
    {
        $s = base64_encode($s);
        $s = str_replace('+', '-', $s);
        $s = str_replace('/', '_', $s);
        return rtrim($s, '=');
    }

    private static function b64urlDecode(string $s): string
    {
        $s = str_replace('-', '+', $s);
        $s = str_replace('_', '/', $s);
        $pad = (4 - strlen($s) % 4) % 4;
        $s .= str_repeat('=', $pad);
        return base64_decode($s, true);
    }
}
