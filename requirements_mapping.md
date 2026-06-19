# Requirements Mapping for `normalize_files.sh`

This document explains how `normalize_files.sh` meets the requirements listed in `requirements.md`.

## Project Scope

The script is a non-trivial Bash utility for file management. It analyzes filenames, normalizes them into a consistent class-file format, previews planned changes, applies renames, and produces reports.

It demonstrates:

- structured Bash programming through separate functions for validation, parsing, normalization, reporting, and renaming
- exit-status driven logic through `if`, `case`, function return values, and command success/failure checks
- controlled parsing and reporting through `find`, `sed`, `grep`, `sort`, `uniq`, `wc`, `head`, and `tee`

## Command-Line Interface

Requirement: Script must be invoked from the command line.

Met by:

```bash
./normalize_files.sh preview [folder]
./normalize_files.sh apply [folder]
./normalize_files.sh stats [folder]
```

Requirement: Must support at least 2 modes or subcommands.

Met by three modes in `main`:

- `preview`
- `apply`
- `stats`

These are validated by the `case` statement in `main`.

Requirement: Must provide a clear usage message when invoked incorrectly.

Met by the `usage` function. It prints valid commands, mode descriptions, and exit-code meanings. `main` calls `usage` when the wrong number of arguments is supplied or when the mode is invalid.

## Functions and Structure

Requirement: Minimum 6 functions.

Met. The script includes more than 6 functions:

- `usage`
- `is_directory`
- `command_exists`
- `has_chapter_prefix`
- `path_is_planned`
- `count_files`
- `make_report_path`
- `smart_word_split`
- `normalize_body`
- `normalize_filename`
- `get_unique_path`
- `print_stats`
- `collect_renames`
- `show_planned_renames`
- `apply_renames`
- `main`

Requirement: One function must be `main`.

Met by `main`, which starts near the bottom of the script and controls argument validation, mode selection, report creation, preview behavior, apply behavior, and exit codes.

Requirement: One function must be `usage`, called when script arguments are incorrect.

Met by `usage`. It is called from `main` when:

- there are too few or too many arguments
- the mode is not `preview`, `apply`, or `stats`

Requirement: At least 2 functions must take input parameters, return only status, and not print output.

Met by:

- `is_directory "$folder"`: takes a folder path and returns success if it is a directory
- `command_exists find`: takes a command name and returns success if it exists
- `has_chapter_prefix "$name"`: takes a filename and returns success if it starts with `chapter_N_`
- `path_is_planned "$next_path"`: takes a path and returns success if it is already planned as a rename target

Requirement: At least 1 function must output data to stdout consumed by command substitution.

Met by several functions:

- `count_files "$folder"` outputs a file count, consumed by `file_count=$(count_files "$folder")`
- `make_report_path "$folder"` outputs a report path, consumed by `report=$(make_report_path "$folder")`
- `normalize_filename "$name"` outputs the cleaned filename, consumed by `normalized=$(normalize_filename "$name")`
- `get_unique_path "$folder/$target"` outputs a safe target path, consumed by `unique_target=$(get_unique_path "$folder/$target")`

Requirement: Only `main` and `usage` may terminate the script.

Met. The `exit` commands are in `main`. `usage` only prints the usage text, while `main` decides the exit code after calling it.

## Exit-Status Driven Logic

Requirement: Must make at least 5 decisions based on exit status.

Met by these examples:

- `if ! is_directory "$folder"; then ... exit 1`
- `if ! command_exists find || ! command_exists sed || ...; then ... exit 1`
- `if command_exists python3; then ...`
- `if has_chapter_prefix "$name"; then ...`
- `if ! collect_renames "$mode" "$folder" "$report"; then ... exit 0`
- `if apply_renames "$report"; then ... exit 0`
- `if mv -- "${OLD_PATHS[$i]}" "${NEW_PATHS[$i]}"; then ... else ... return 1`
- `while [[ -e "$next_path" ]] || path_is_planned "$next_path"; do ...`

These checks distinguish success from failure and choose different behavior based on the result.

## Exit Codes

Requirement: Use these exit codes:

- `0` pass/success
- `1` fail
- `2` incorrect usage

Met in `main`:

- `exit 0` for successful `stats`, successful `preview`, successful `apply`, no files found, no queued renames, or user cancellation
- `exit 1` for invalid folders, missing required commands, or failed rename operations
- `exit 2` for incorrect usage or invalid subcommands

## Command-Line Tools

Requirement: Must use at least 5 standard CLI tools invoked directly.

Met. The script invokes more than 5 standard tools:

- `basename`
- `dirname`
- `find`
- `wc`
- `tr`
- `date`
- `sed`
- `sort`
- `uniq`
- `grep`
- `head`
- `tee`
- `mv`

Examples:

- `find` locates files in the selected folder
- `wc -l` counts files
- `sed` cleans filename patterns
- `sort` orders file lists and report summaries
- `uniq -c` creates extension counts
- `head -5` limits the top-extension list
- `tee` writes stats to both stdout and a report file
- `mv` performs the actual rename operation

## Redirection Requirements

Requirement: Must use redirection at least 7 times.

Met. The script uses redirection many times, including:

- `>/dev/null` in `command_exists`
- `2>&1` in `command_exists`
- `2>/dev/null` in `count_files`
- `2>/dev/null` in `print_stats`
- `2>/dev/null` in `collect_renames`
- `>> "$report"` throughout `collect_renames`
- `>> "$report"` in `show_planned_renames`
- `>> "$report"` in `apply_renames`
- `: > "$report"` to create or clear the report file
- `>&2` when printing error messages
- `3< <(...)` to feed the file list into the loop without consuming normal keyboard input

## Output Parsing and Manipulation

Requirement: Must compute derived metrics using parsing pipelines.

Met in `print_stats` and `count_files`.

Derived metrics include:

- total file count
- number of files with a `chapter_N_` prefix
- number of files containing `-Tagged`
- number of duplicate filename stems
- top 5 file extensions

Example pipelines:

```bash
find "$folder" -maxdepth 1 -type f ... | wc -l | tr -d ' '
```

```bash
find "$folder" -maxdepth 1 -type f ... |
    sed -nE 's/^.*\.([^.]+)$/\1/p' |
    tr '[:upper:]' '[:lower:]' |
    sort |
    uniq -c |
    sort -rn |
    head -5
```

Filename parsing and manipulation also happen in `normalize_body` and `normalize_filename`, where `sed`, `tr`, Bash regex checks, string operations, and command substitution are used to clean names.

## Testability

Requirement: Project must be fully testable on a local machine and require no privileged access.

Met. The script works on local folders and normal user-owned files. It does not require `sudo`, system directories, remote access, or special privileges.

The README includes local test steps using a `test_files` folder and `touch` commands.

Useful local tests:

```bash
bash -n normalize_files.sh
./normalize_files.sh
./normalize_files.sh preview test_files
./normalize_files.sh stats test_files
./normalize_files.sh apply test_files
```

## Required Output

Requirement: Each script must produce human-readable output.

Met. The script prints readable messages such as:

- current mode
- folder being scanned
- number of files found
- each file being processed
- queued rename pairs
- planned rename summary
- stats report
- final success, cancellation, or failure messages

Requirement: Optional report file.

Met. Every mode writes a timestamped report file named like:

```text
normalize_report_YYYYMMDD_HHMMSS_PID.txt
```

The report captures the same important information that appears in the terminal.

## Deliverables

Requirement: Bash script as a single `.sh` file.

Met by:

```text
normalize_files.sh
```

Requirement: `README.md` must include project description, supported modes and options, exit code meanings, and how to test locally.

Met by:

```text
README.md
```

The README includes:

- project description
- supported modes
- command examples
- report file explanation
- exit code meanings
- local testing instructions

## Code Defense Notes

Important parts to be ready to explain:

- Why `main` owns the script exits
- How `usage` works with incorrect arguments
- How `is_directory`, `command_exists`, `has_chapter_prefix`, and `path_is_planned` return status only
- How command substitution captures function output
- Why `3< <(...)` is used in `collect_renames`
- How report writing uses redirection
- How `print_stats` computes derived metrics with pipelines
- How the script avoids overwriting files with `get_unique_path`
- How the optional Python/`wordninja` bridge works inside `smart_word_split`
