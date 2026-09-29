# 开发与调试

先看 [README.md](README.md) 把依赖装好并成功跑过一次 `./build.sh`。这篇只写改代码时会碰到的事。

## 改哪里

| 想改的行为 | 改这里 | 不用改 |
|---|---|---|
| 某个工具的计算、参数、按钮文案 | `src/tools/XxxTool.php` | 事件循环、侧边栏 |
| 新增一个工具 | 新类 + `src/Registry.php` 的 `allTools()` 加一行 `new XxxTool()` | `src/main.php`、`src/gui/` |
| 窗口布局、点按钮后怎么取输入、怎么写输出 | `src/gui/GuiApp.php` | 桥接，除非缺一个 `ui_*` |
| 控件、事件、查找、颜色、Dock 图标 | `objc-src/macos_bridge.mm`，并在 `objc-src/macos_bridge.stub.php` 声明同名的 `ui_*` | 工具类 |

CLI 入口是 `src/main.php` 的 `main(int $argc, array $argv)`。GUI 入口是 `src/gui/main.php` 的 `main()`。`project.yml` 忽略 `src/gui`，`project-gui.yml` 忽略 `src/main.php`，所以两个二进制不会把对方的入口编进去。工具类两边都编。

一个工具要同时实现 `run()` 和 `guiRun()`。两边应共用同一段私有逻辑，避免命令行和窗口各算各的。`guiActions()` 返回的字符串就是 `guiRun()` 收到的 `$action`。`guiParamLabel()` 返回 `''` 时窗口不显示参数框。

## 编完怎么看

```bash
./build.sh
./aotbox jwt decode '<token>'          # 命令行
./aotbox-gui                           # 窗口（从终端启动）
./package-app.sh                        # 生成 Aotbox.app，双击它不会弹出终端
```

`./build.sh` 会把多余参数传给编译器。链接报下面的「命名空间对不上」时：

```bash
./build.sh -f
```

`-f` 清掉增量缓存，CLI 和 GUI 各完整生成一次。

本机 `php` 若是 8.2，编译器跑不起来。用 8.4 或 8.5：

```bash
export PHP_BIN=/opt/homebrew/opt/php@8.4/bin/php
./build.sh
```

日志里出现 `Restarting tpc with PHP 8.5` 是正常的：编译器改用 `~/.typephp` 里那份私有运行时，和你 PATH 上的 PHP 不是同一个。

只改了 `objc-src/macos_bridge.mm` 时，成功编过一次之后的增量编译通常只重编这个文件。改了 `src/tools/` 之后不要只编其中一个工程，见下一节。

## 链接失败：命名空间对不上

CLI 工程名是 `aotbox`，GUI 是 `aotbox-gui`。两边都编译 `src/tools/`。TypePHP 按源文件路径缓存生成的 C++。先编完 CLI，再增量编 GUI 时，工具的目标文件可能还在引用 `typephp_project_aotbox::`，而 GUI 扩展提供的是 `typephp_project_aotbox_gui::`。

典型报错：

```text
Undefined symbols for architecture arm64:
  "typephp_project_aotbox::get_persistent_func(...)"
```

处理：`./build.sh -f`。不要只对 `project-gui.yml` 做一次不带 `-f` 的增量编译来「省时间」。

## GUI 一点按钮就退出

事件循环在 `src/gui/main.php`：`ui_next_event()` 返回值 `< 0` 就结束进程。关窗口时桥接返回 `-1`。

按钮的控件 ID 写在 `NSButton.tag` 上。`NSButton` 的 tag 默认就是 `-1`。创建按钮时如果没把 ID 写进去，每次点击都会被当成关窗口。

约定在 `store_control`：

- ID 从 1 开始。`0` 表示「这次没有点击」。
- 只有关窗口才返回负数。
- 新建的可点击控件必须把 ID 写入 `tag`。

输出区是只读的，但可选中。查找走菜单「查找」（`Command-F`）。焦点在按钮上时，查找落在输出区；焦点已经在输入框里时，查找落在输入框。

## 颜色和图标不在工具类里

`ui_set_control_text` 写到文本框时顺带上色：

- 整段是一个 JSON 值：按键、字符串、数字、字面量上色。
- 整段是 `header.payload.signature` 这种令牌：三段分别上色。
- 文本以「签名有效」「签名校验失败」「未校验签名」开头：第一行用状态色，中间的 JSON 仍按上面的规则上色。
- 都不是：纯文本。所以「请输入密钥」不会被上色。

命令行没有这层，打印出来就是纯文本。

Dock 图标是 `make_app_icon()`，在 `ui_app_init` 里赋给 `NSApp.applicationIconImage`。没有图片文件。

## TypePHP 子集

编不过时先对照这些限制，而不是换成普通 PHP 的写法：

- 文件开头 `declare(strict_types=1);`，函数有显式返回类型。
- 不要写闭包、不要写 `exit()`、不要在运行时拼函数名再调用。
- 新工具必须在 `allTools()` 里 `new` 出来。没有自动扫描目录。
- `ui_*` 的声明在 `macos_bridge.stub.php`，实现是 `macos_bridge.mm` 里的 `php_ui_*`。只加声明、不写 `php_ui_*`，链接会缺符号。

## 怀疑是桥接而不是工具逻辑

`diag.php` / `diag.yml` 不在 `./build.sh` 里。它只做三步：读文本框、`json_encode`、写回文本框，并在标准输出打出走到哪一步。用来区分「计算崩了」和「写控件崩了」。

正式功能不要加进 `diag.php`。
