#!/usr/bin/env bash
set -euo pipefail

# Build `aotbox` as a native binary using TypePHP (AOT compiler).
#
# One-time prerequisites:
#   - PHP 8.4 or 8.5 on PATH (used only to run the TypePHP compiler itself)
#   - Homebrew:  brew install cmake gmp mpfr pkg-config libiconv oniguruma
#   - PHPX:      git clone https://github.com/swoole/phpx.git /tmp/phpx && build it
#   - TypePHP:   git clone https://github.com/swoole/typephp.git /tmp/typephp-ref
#                && (cd /tmp/typephp-ref && composer install)
#
# See README.md for the exact PHPX / TypePHP setup commands.
#
# Environment overrides:
#   TYPEPHP_DIR  TypePHP source checkout        (default /tmp/typephp-ref)
#   PHPX_HOME    built PHPX (lib/libphpx.dylib) (default /tmp/phpx)
#   PHP_BIN      PHP binary >= 8.4              (default php)

HERE="$(cd "$(dirname "$0")" && pwd)"
TYPEPHP_DIR="${TYPEPHP_DIR:-/tmp/typephp-ref}"
PHPX_HOME="${PHPX_HOME:-/tmp/phpx}"
PHP_BIN="${PHP_BIN:-php}"

export PHPX_HOME

# --- macOS / Homebrew workarounds -------------------------------------------
# TypePHP's php-builder compiles a private PHP runtime + a static PHPX from
# source. On macOS these need a few paths that are not on the compiler's
# default search path:
#   1. pkg-config may be shadowed by a MacPorts install -> use Homebrew's.
#   2. the static PHPX build does not add /opt/homebrew/include, so gmp/mpfr
#      headers are not found -> expose them via CPATH (clang reads it at every
#      compile, independent of cmake caching).
#   3. libiconv is keg-only, so the final link needs its directory explicitly.
LINK_PATH_FLAG=""
if [[ "$(uname -s)" == "Darwin" && -d /opt/homebrew ]]; then
    export PKG_CONFIG="${PKG_CONFIG:-/opt/homebrew/bin/pkg-config}"
    export PKG_CONFIG_PATH="${PKG_CONFIG_PATH:-/opt/homebrew/lib/pkgconfig:/opt/homebrew/opt/openssl@3/lib/pkgconfig}"
    export CPATH="${CPATH:-/opt/homebrew/include}"
    LINK_PATH_FLAG="--link-path /opt/homebrew/opt/libiconv/lib"
fi

# php-builder compiles a private PHP runtime from php-src on first build
# (cached under ~/.typephp). `zts: off` is correct for a single-threaded CLI.
# shellcheck disable=SC2086
for project in project.yml project-gui.yml; do
    "${PHP_BIN}" "${TYPEPHP_DIR}/bin/tpc.php" "${HERE}/${project}" \
        --php-builder='extensions: []; zts: off' \
        ${LINK_PATH_FLAG} \
        --no-progress "$@"
done

echo "Built: ${HERE}/aotbox (CLI) and ${HERE}/aotbox-gui (GUI)"
