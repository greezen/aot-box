# Aotbox

一个用 [TypePHP](https://github.com/swoole/typephp)（PHP AOT 编译器）**原生编译**的开发者常用工具箱。仓库里是 PHP 源码；`./build.sh` 把它编成两个原生二进制：`aotbox`（命令行）和 `aotbox-gui`（macOS 窗口）。发给使用者的是二进制，不是解释执行的 PHP。

## 图形界面（macOS 原生）

`aotbox-gui` 是同一套工具逻辑的 **macOS 原生 GUI**，用系统自带的 AppKit 组件（NSWindow / NSButton / NSTextField / NSTextView）构建，无需浏览器：

```bash
./aotbox-gui        # 终端里打开窗口
./package-app.sh     # 生成 Aotbox.app，访达里双击它
```

双击裸的 `aotbox-gui` 会打开终端黑窗口。双击 `Aotbox.app` 不会。`./package-app.sh` 把编好的二进制拷进 `.app`，所以每次 `./build.sh` 之后要再跑一次，双击到的才是新二进制。

左侧是工具列表，右侧是输入区、参数区、操作按钮和只读输出区。界面布局、状态与点击行为在 `src/gui/`；AppKit 调用在 `objc-src/macos_bridge.mm`。点击按钮把控件 ID 交回 `src/gui/main.php` 的事件循环。

`Aotbox.app` 的文件图标是蓝底、白色 `{ }`、底部一条琥珀色，由 `package-app.sh` 写进 `AppIcon.icns`。程序跑起来之后，Dock 里用的是同一张图。

输出区会给整段 JSON 上色；JWT 解码会给状态行和其中的 JSON 上色，编码得到的令牌按三段上色。在输出区按 `Command-F` 查找。这些都在桥接里，不在各个工具类里。

改代码、只编一个目标、链接失败和「一点按钮程序就退出」见 [DEVELOPMENT.md](DEVELOPMENT.md)。

## 内置工具

| 命令 | 说明 | 示例 |
|------|------|------|
| `json` | JSON 格式化 / 压缩 / 校验 | `aotbox json '{"b":1,"a":[1,2]}'` |
| `base64` | Base64 编码 / 解码（含 URL 安全） | `aotbox base64 hello` · `aotbox base64 -d aGVsbG8=` |
| `url` | URL 编码 / 解码（含 raw） | `aotbox url 'hello world'` |
| `hash` | MD5 / SHA 系列哈希 | `aotbox hash sha256 abc` |
| `time` | Unix 时间戳与日期互转 | `aotbox time 1700000000` · `aotbox time -t '2024-01-01 12:00:00'` |
| `jwt` | JWT 编码 / 解码（HS256/384/512）。解码可以不给密钥，只读出内容、不校验签名 | `aotbox jwt encode '{"sub":"1"}' secret` · `aotbox jwt decode <token>` · `aotbox jwt decode <token> secret` |
| `uuid` | 生成 UUID v4 / v7 | `aotbox uuid 7 5` |

`aotbox help` 或 `aotbox help <工具>` 查看用法。

## 快速开始（macOS 原生构建）

前置：Homebrew、clang（Xcode Command Line Tools）。产物为 **arm64 原生二进制**，`libphp` / `libphpx` 已静态链接进二进制，运行时仅依赖系统库 + 少数 Homebrew 库（gmp / mpfr / libiconv / oniguruma）。

```bash
# 1. 构建依赖（gmp/mpfr 是 PHPX 的 bigInt/bigFloat 所需；libiconv/oniguruma 是
#    php-builder 从源码编译私有 PHP 运行时所需）
brew install cmake gmp mpfr pkg-config libiconv oniguruma

# 2. PHP 8.4/8.5（仅用于运行 TypePHP 编译器，编译产物不依赖它）
brew install php@8.4
export PATH="/opt/homebrew/opt/php@8.4/bin:$PATH"

# 3. TypePHP 编译器 + PHPX 桥接库
git clone https://github.com/swoole/typephp.git /tmp/typephp-ref
(cd /tmp/typephp-ref && composer install)

git clone https://github.com/swoole/phpx.git /tmp/phpx
cmake -S /tmp/phpx -B /tmp/phpx/build -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_TESTS=OFF -DBUILD_EXT=OFF -Dphp_dir="$(php-config --prefix)"
cmake --build /tmp/phpx/build --target phpx --parallel 4

# 4. 编译本工具箱（首次会由 php-builder 从 php-src 构建私有 PHP 运行时，较慢，之后缓存）
./build.sh

# 5. 运行
./aotbox --help
./aotbox json '{"hello":"world"}'
```

`build.sh` 支持 `TYPEPHP_DIR` / `PHPX_HOME` / `PHP_BIN` 环境变量覆盖路径。

### macOS 构建注意事项（build.sh 已自动处理）

macOS + Homebrew 下从源码构建有 3 个坑，`build.sh` 已全部自动处理：

1. **pkg-config 被 MacPorts 抢占**：若 `/opt/local/bin/pkg-config` 排在 PATH 前面，php-src 的 configure 会用它而找不到 oniguruma。→ 显式设 `PKG_CONFIG=/opt/homebrew/bin/pkg-config`。
2. **gmp/mpfr 头文件找不到**：php-builder 用 `phpx/sapi-static` 构建静态 PHPX，该 CMakeLists 不加 `/opt/homebrew/include`，`mpfr.h`/`gmpxx.h` 找不到。→ 设 `CPATH=/opt/homebrew/include`（clang 每次编译都读取，不受 cmake 缓存影响）。
3. **libiconv 是 keg-only**：最终链接需要 `libiconv_open`（Homebrew 前缀符号），但它的 lib 不在默认搜索路径。→ 加 `--link-path /opt/homebrew/opt/libiconv/lib`。

## 架构

```
src/
├── main.php        # CLI 入口：main(argc, argv)，命令分发
├── Tool.php        # 工具插件接口（CLI 的 run + GUI 的 gui* 方法）
├── Registry.php    # allTools()：唯一的插件注册点
├── tools/          # 每个工具 = 一个独立类，实现 Tool 接口
│   ├── JsonTool.php
│   ├── Base64Tool.php
│   ├── UrlTool.php
│   ├── HashTool.php
│   ├── TimestampTool.php
│   ├── JwtTool.php
│   └── UuidTool.php
└── gui/            # macOS 原生 GUI（AppKit）
    ├── main.php    # GUI 入口 + 事件循环
    └── GuiApp.php  # 窗口布局、状态、点击行为

objc-src/           # Objective-C++ 桥接（AppKit）
├── macos_bridge.stub.php   # ui_* 函数声明（映射到 php_ui_* 实现）
└── macos_bridge.mm         # 原生控件实现

project.yml         # CLI 构建配置
project-gui.yml     # GUI 构建配置（链接 AppKit/Foundation）
```

**插件机制**：每个工具是自包含的类，实现统一的 `Tool` 接口。由于 TypePHP 是 AOT 编译，插件在**编译期静态注册**（`Registry.php` 中 `new XxxTool()`），不存在运行时 `glob` + 反射的自动发现。

**新增一个工具**：在 `src/tools/` 写一个实现 `Tool` 的类（含 `run` + `guiActions`/`guiParamLabel`/`guiRun`），在 `Registry.php` 的 `allTools()` 里加一行 `new XxxTool()`。CLI 分发、GUI 侧边栏与事件循环都零改动。

## TypePHP 兼容性说明

- 代码遵循 TypePHP 的可编译子集：`declare(strict_types=1)`、显式返回类型、无闭包 / 无 `exit()` / 无运行时动态调用。
- 使用内置函数通过 PHPX 与 Zend runtime 互通：`json_*`、`base64_*`、`urlencode`、`hash`、`hash_hmac`、`date`/`gmdate`/`time`、`strtotime`、`random_int`、`random_bytes`、`microtime`、`sprintf`、`substr` 等均为 Zend 内置，运行时可用。
- 二进制由 `php-builder` 构建的私有 PHP 运行时支撑，宿主无需 `libphp.dylib`。

## 路线图（先有后好）

- [ ] stdin 输入支持（`aotbox base64 -d` 从管道读取）
- [ ] 更多算法（JWT RS256/ES256、HMAC 哈希、CRC）
- [ ] 交互式 Web UI（HTTP 服务模式，复用同一套工具函数）
- [x] GUI 输出上色（整段 JSON；JWT 的状态行、内嵌 JSON、三段令牌）。命令行仍是纯文本
- [ ] 单元测试与 CI

## License

MIT
