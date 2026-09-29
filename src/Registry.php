<?php

declare(strict_types=1);

/**
 * Static registry of all toolbox tools.
 *
 * This is the single registration point: to add a tool, create the class and
 * add `new XxxTool()` here. TypePHP resolves the full symbol set at compile
 * time, so there is no runtime discovery or autoloading.
 */
function allTools(): array
{
    return [
        new JsonTool(),
        new Base64Tool(),
        new UrlTool(),
        new HashTool(),
        new TimestampTool(),
        new JwtTool(),
        new UuidTool(),
    ];
}
