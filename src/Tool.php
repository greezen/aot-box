<?php

declare(strict_types=1);

/**
 * A single tool (plugin) in the toolbox.
 *
 * Each tool is one self-contained class implementing this interface, dropped
 * into src/tools/ and registered in Registry.php. It is resolved statically at
 * compile time (TypePHP AOT), so adding/removing a tool never touches core
 * dispatch logic — only the registry entry.
 */
interface Tool
{
    /** Command name, e.g. "json". */
    public function name(): string;

    /** One-line description shown in the tool list. */
    public function description(): string;

    /** Full usage text for `aotbox help <name>`. */
    public function usage(): string;

    /** Execute the tool. Returns the process exit code. */
    public function run(array $args): int;

    /**
     * GUI: labels of the action buttons shown for this tool.
     *
     * @return list<string>
     */
    public function guiActions(): array;

    /** GUI: label of the optional secondary parameter field ('' hides it). */
    public function guiParamLabel(): string;

    /** GUI: run the tool. `input` is the main text, `param` the secondary
     *  field, `action` one of guiActions(). Returns the result text. */
    public function guiRun(string $input, string $param, string $action): string;
}
