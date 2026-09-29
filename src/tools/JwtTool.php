<?php

declare(strict_types=1);

class JwtTool implements Tool
{
    public function name(): string
    {
        return 'jwt';
    }

    public function description(): string
    {
        return 'JWT 编码 / 解码（HS256/384/512）';
    }

    public function usage(): string
    {
        return "用法:\n"
            . "  aotbox jwt encode <payload-json> <secret> [HS256|HS384|HS512]\n"
            . "  aotbox jwt decode <token> [secret]\n"
            . "    省略 secret 只解码 header/payload，不校验签名\n";
    }

    public function run(array $args): int
    {
        $n = count($args);
        if ($n < 1) {
            echo $this->usage();
            return 1;
        }

        $sub = $args[0];

        if ($sub === 'encode') {
            if ($n < 3) {
                echo $this->usage();
                return 1;
            }
            $alg = $n >= 4 ? strtoupper($args[3]) : 'HS256';
            return $this->encode($args[1], $args[2], $alg);
        }

        if ($sub === 'decode') {
            if ($n < 2) {
                echo $this->usage();
                return 1;
            }
            $secret = $n >= 3 ? $args[2] : '';
            return $this->decode($args[1], $secret);
        }

        echo $this->usage();
        return 1;
    }

    public function guiActions(): array
    {
        return ['编码', '解码'];
    }

    public function guiParamLabel(): string
    {
        return '密钥 secret（解码可留空）';
    }

    public function guiRun(string $input, string $param, string $action): string
    {
        if ($action === '编码') {
            if ($param === '') {
                return '请输入密钥 secret';
            }
            $data = json_decode($input, true);
            if (json_last_error() !== JSON_ERROR_NONE || !is_array($data)) {
                return 'Payload 不是合法 JSON';
            }
            $header = self::b64urlEncode(json_encode(['alg' => 'HS256', 'typ' => 'JWT'], JSON_UNESCAPED_SLASHES));
            $body = self::b64urlEncode(json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES));
            $sig = self::b64urlEncode(hash_hmac('sha256', $header . '.' . $body, $param, true));
            return $header . '.' . $body . '.' . $sig;
        }

        $report = $this->decodeReport($input, $param);
        return $report[1];
    }

    private function encode(string $payload, string $secret, string $alg): int
    {
        $data = json_decode($payload, true);
        if (json_last_error() !== JSON_ERROR_NONE || !is_array($data)) {
            echo "Payload 不是合法 JSON\n";
            return 1;
        }

        $header = self::b64urlEncode(json_encode(['alg' => $alg, 'typ' => 'JWT'], JSON_UNESCAPED_SLASHES));
        $body = self::b64urlEncode(json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES));
        $sig = self::b64urlEncode(hash_hmac(self::algo($alg), $header . '.' . $body, $secret, true));

        echo $header . '.' . $body . '.' . $sig . "\n";
        return 0;
    }

    private function decode(string $token, string $secret): int
    {
        $report = $this->decodeReport($token, $secret);
        echo $report[1] . "\n";
        return $report[0];
    }

    /** @return array{0:int,1:string}  exit code, display text */
    private function decodeReport(string $token, string $secret): array
    {
        $parts = explode('.', $token);
        if (count($parts) !== 3) {
            return [1, 'JWT 应包含三段（header.payload.signature）'];
        }

        $headerRaw = self::b64urlDecode($parts[0]);
        $payloadRaw = self::b64urlDecode($parts[1]);
        if (($parts[0] !== '' && $headerRaw === '') || ($parts[1] !== '' && $payloadRaw === '')) {
            return [1, 'header 或 payload 不是合法 Base64'];
        }

        $header = json_decode($headerRaw, true);
        $alg = is_array($header) && isset($header['alg']) ? (string) $header['alg'] : 'HS256';

        $code = 0;
        if ($secret === '') {
            $status = '未校验签名（未提供密钥）';
        } else {
            $expected = self::b64urlEncode(hash_hmac(self::algo($alg), $parts[0] . '.' . $parts[1], $secret, true));
            if (!hash_equals($expected, $parts[2])) {
                $status = '签名校验失败（密钥不匹配）';
                $code = 1;
            } else {
                $status = '签名有效 ✓（' . $alg . '）';
            }
        }

        $flags = JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES;
        $headerText = is_array($header) ? json_encode($header, $flags) : $headerRaw;
        $payload = json_decode($payloadRaw, true);
        $payloadText = is_array($payload) ? json_encode($payload, $flags) : $payloadRaw;

        return [$code, $status . "\n\nheader:\n" . $headerText . "\n\npayload:\n" . $payloadText];
    }

    private static function algo(string $alg): string
    {
        if ($alg === 'HS384') {
            return 'sha384';
        }
        if ($alg === 'HS512') {
            return 'sha512';
        }
        return 'sha256';
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
        $raw = base64_decode($s, true);
        return is_string($raw) ? $raw : '';
    }
}
