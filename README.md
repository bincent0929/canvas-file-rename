# Normalize Files Bash Utility

## Project Description

`normalize_files.sh` is a Bash command-line utility for copying class files into a `normalized` folder with consistent `chapter_N_readable_name.ext` filenames. It is based on the behavior of `normalize_files.py`.

The script cleans common Canvas/download filename patterns:

- removes `-Tagged`
- removes copy markers such as `(1)` and trailing `-1`
- removes leading download labels such as `Slides 6.11 Ch 6` and `Ch 5`
- changes `&` to `and`
- removes commas
- converts spaces, periods, and hyphens into underscores
- preserves existing `chapter_N_` prefixes
- prompts for a chapter number when a file does not already have one
- keeps the original files unchanged
- avoids overwriting existing normalized files by adding `_1`, `_2`, and so on

For merged words, the script uses `python3` with `wordninja` if that library is installed. If `wordninja` is not installed, it falls back to a small built-in splitter for the class filename words used by this project.

## Supported Modes

```bash
./normalize_files.sh preview [folder]
./normalize_files.sh apply [folder]
./normalize_files.sh stats [folder]
```

If no folder is supplied, use `.` for the current folder.

### `preview`

Shows the planned filename changes without copying files.

```bash
./normalize_files.sh preview ./sample_files
```

### `apply`

Shows the planned filename changes, asks for confirmation, then copies the files into a `normalized` folder.

```bash
./normalize_files.sh apply ./sample_files
```

### `stats`

Prints a short report with file counts, chapter-prefix counts, tagged-file counts, duplicate stem counts, and top file extensions.

```bash
./normalize_files.sh stats ./sample_files
```

Each mode creates the `normalized` folder and writes a timestamped report file there named like:

```text
normalize_report_YYYYMMDD_HHMMSS_PID.txt
```

## Exit Codes

- `0` success
- `1` failure
- `2` incorrect usage

## How To Test Locally

Create a temporary folder:

```bash
mkdir -p test_files
touch "test_files/Slides 6.11 Ch 6 Physical, Cognitive and Socio emotional Dev in Toddlerhood.pptx"
touch "test_files/Ch 5 Physical, Cognitive and Socio emotional Dev in Infancy.pptx"
touch "test_files/ThinkingaboutChildDevelopmentCurrent&CulturalPerspectives(2)-Tagged.pdf"
touch "test_files/chapter_4_Birthandthenewbornchild.(1)-Tagged.pdf"
touch "test_files/GeneticsandPrenatalDevelopment-1.pdf"
```

Run a preview:

```bash
./normalize_files.sh preview test_files
```

When prompted for chapter numbers, enter a number or press Enter to skip that file.

Run the stats mode:

```bash
./normalize_files.sh stats test_files
```

Run the apply mode:

```bash
./normalize_files.sh apply test_files
```

Confirm with `y` to copy the files into `test_files/normalized`.
