#!/usr/bin/env bash

PROGRAM_NAME=$(basename "$0")
PLANNED_TARGETS=()

usage() {
    cat <<USAGE
Usage:
  $PROGRAM_NAME preview [folder]
  $PROGRAM_NAME apply [folder]
  $PROGRAM_NAME stats [folder]

Modes:
  preview   Show proposed normalized filenames without renaming files
  apply     Show proposed filenames, confirm, then rename files
  stats     Summarize filename patterns in the folder

Exit codes:
  0  success
  1  failure
  2  incorrect usage
USAGE
}

is_directory() {
    [[ -d "$1" ]]
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

has_chapter_prefix() {
    local name stem
    name=$(basename "$1")
    stem=${name%.*}
    [[ "$stem" =~ ^[Cc][Hh][Aa][Pp][Tt][Ee][Rr]_[0-9]+_ ]]
}

path_is_planned() {
    local candidate planned
    candidate=$1
    for planned in "${PLANNED_TARGETS[@]}"; do
        [[ "$planned" == "$candidate" ]] && return 0
    done
    return 1
}

count_files() {
    find "$1" -maxdepth 1 -type f ! -name "$PROGRAM_NAME" ! -name 'normalize_report_*.txt' -print 2>/dev/null | wc -l | tr -d ' '
}

make_report_path() {
    local folder stamp
    folder=$1
    stamp=$(date '+%Y%m%d_%H%M%S')
    printf '%s/normalize_report_%s_%s.txt\n' "$folder" "$stamp" "$$"
}

smart_word_split() {
    local text
    text=$1

    if [[ -z "$text" ]]; then
        printf '\n'
        return 0
    fi

    if command_exists python3; then
        python3 - "$text" <<'PY'
import re
import sys

text = sys.argv[1]

try:
    import wordninja
    print("_".join(wordninja.split(text)))
    sys.exit(0)
except Exception:
    pass

known = {
    "about", "adolescence", "adulthood", "and", "birth", "chapter", "child",
    "cognitive", "current", "cultural", "development", "dev", "emotional",
    "genetics", "infancy", "newborn", "perspectives", "physical", "prenatal",
    "socio", "slides", "the", "thinking", "toddlerhood"
}

def segment(chunk):
    if chunk.isdigit() or len(chunk) <= 3:
        return [chunk]

    words = []
    lower = chunk.lower()
    i = 0
    while i < len(lower):
        best = None
        for j in range(len(lower), i, -1):
            piece = lower[i:j]
            if piece in known:
                best = piece
                break
        if best is None:
            words.append(chunk[i:])
            break
        words.append(best)
        i += len(best)
    return words

pieces = re.sub(r"([a-z])([A-Z])", r"\1 \2", text).split()
out = []
for piece in pieces:
    segmented = segment(piece)
    if piece[:1].isupper():
        out.extend(word.capitalize() if word.isalpha() and word not in {"and", "the"} else word for word in segmented)
    else:
        out.extend(segmented)

print("_".join(out))
PY
        return $?
    fi

    printf '%s\n' "$text"
}

normalize_body() {
    local stem cleaned part split_part cleaned_parts
    stem=$1
    cleaned_parts=()

    stem=$(printf '%s' "$stem" | sed -E 's/-[Tt][Aa][Gg][Gg][Ee][Dd]$//')
    stem=$(printf '%s' "$stem" | sed -E 's/\([0-9]+\)//g')
    stem=$(printf '%s' "$stem" | sed -E 's/-[0-9]+$//')
    stem=$(printf '%s' "$stem" | sed -E 's/&/ and /g; s/,//g; s/\.{2,}/./g')
    stem=$(printf '%s' "$stem" | sed -E 's/^[Ss]lides[[:space:]]+[0-9]+(\.[0-9]+)*[[:space:]]+[Cc][Hh][[:space:]]*[0-9]+[[:space:]]+//')
    stem=$(printf '%s' "$stem" | sed -E 's/^[Cc][Hh][[:space:]]*[0-9]+[[:space:]]+//')
    stem=$(printf '%s' "$stem" | sed -E 's/([[:lower:]])([[:upper:]])/\1 \2/g')

    while IFS= read -r part; do
        part=$(printf '%s' "$part" | sed -E 's/^_+//; s/_+$//')

        [[ -z "$part" ]] && continue

        if [[ "$part" =~ ^[Cc][Hh][0-9]+$ ]]; then
            cleaned_parts+=("$part")
            continue
        fi

        if [[ "$part" =~ ^[0-9]+$ ]]; then
            cleaned_parts+=("$part")
            continue
        fi

        split_part=$(smart_word_split "$part")
        cleaned_parts+=("$split_part")
    done < <(printf '%s\n' "$stem" | tr '[:space:].-' '\n')

    cleaned=$(IFS=_; printf '%s' "${cleaned_parts[*]}")
    cleaned=$(printf '%s' "$cleaned" | sed -E 's/_+/_/g; s/^_+//; s/_+$//')
    printf '%s\n' "$cleaned"
}

normalize_filename() {
    local name stem suffix prefix cleaned
    name=$(basename "$1")
    suffix=""

    if [[ "$name" == *.* && "$name" != .* ]]; then
        suffix=".${name##*.}"
        stem=${name%.*}
    else
        stem=$name
    fi

    prefix=""
    if [[ "$stem" =~ ^([Cc][Hh][Aa][Pp][Tt][Ee][Rr]_[0-9]+_) ]]; then
        prefix=$(printf '%s' "${BASH_REMATCH[1]}" | tr '[:upper:]' '[:lower:]')
        stem=${stem:${#BASH_REMATCH[1]}}
    fi

    cleaned=$(normalize_body "$stem")
    printf '%s%s%s\n' "$prefix" "$cleaned" "$suffix"
}

get_unique_path() {
    local candidate folder name stem suffix counter next_path
    candidate=$1
    folder=$(dirname "$candidate")
    name=$(basename "$candidate")
    suffix=""

    if [[ "$name" == *.* && "$name" != .* ]]; then
        suffix=".${name##*.}"
        stem=${name%.*}
    else
        stem=$name
    fi

    counter=1
    next_path=$candidate
    while [[ -e "$next_path" ]] || path_is_planned "$next_path"; do
        next_path="$folder/${stem}_${counter}${suffix}"
        counter=$((counter + 1))
    done

    printf '%s\n' "$next_path"
}

print_stats() {
    local folder total chapter_count tagged_count duplicate_stems report
    folder=$1
    report=$2

    total=$(count_files "$folder")
    chapter_count=$(find "$folder" -maxdepth 1 -type f ! -name 'normalize_report_*.txt' -printf '%f\n' 2>/dev/null | grep -Eic '^chapter_[0-9]+_')
    tagged_count=$(find "$folder" -maxdepth 1 -type f ! -name 'normalize_report_*.txt' -printf '%f\n' 2>/dev/null | grep -Eic -- '-Tagged\.')
    duplicate_stems=$(find "$folder" -maxdepth 1 -type f ! -name 'normalize_report_*.txt' -printf '%f\n' 2>/dev/null | sed -E 's/\.[^.]+$//' | sort | uniq -d | wc -l | tr -d ' ')

    {
        printf 'Filename normalization stats\n'
        printf 'Folder: %s\n' "$folder"
        printf 'Total files: %s\n' "$total"
        printf 'Files with chapter prefix: %s\n' "$chapter_count"
        printf 'Files with -Tagged marker: %s\n' "$tagged_count"
        printf 'Duplicate filename stems: %s\n' "$duplicate_stems"
        printf '\nTop extensions:\n'
        find "$folder" -maxdepth 1 -type f ! -name 'normalize_report_*.txt' -printf '%f\n' 2>/dev/null |
            sed -nE 's/^.*\.([^.]+)$/\1/p' |
            tr '[:upper:]' '[:lower:]' |
            sort |
            uniq -c |
            sort -rn |
            head -5
    } | tee "$report"
}

collect_renames() {
    local mode folder report file name normalized chapter_number target unique_target
    mode=$1
    folder=$2
    report=$3

    OLD_PATHS=()
    NEW_PATHS=()
    PLANNED_TARGETS=()

    while IFS= read -r -d '' -u 3 file; do
        name=$(basename "$file")
        printf '\nFile: %s\n' "$name"
        printf '\nFile: %s\n' "$name" >> "$report"

        normalized=$(normalize_filename "$name")

        if has_chapter_prefix "$name"; then
            target=$normalized
            printf 'Chapter prefix already found; not prompting for chapter number.\n'
            printf 'Chapter prefix already found; not prompting for chapter number.\n' >> "$report"
        else
            printf 'Enter chapter number for this file, or press Enter to skip: '
            IFS= read -r chapter_number

            if [[ -z "$chapter_number" ]]; then
                printf 'Skipped.\n'
                printf 'Skipped.\n' >> "$report"
                continue
            fi

            if [[ ! "$chapter_number" =~ ^[0-9]+$ ]]; then
                printf 'Invalid chapter number; skipped.\n'
                printf 'Invalid chapter number; skipped.\n' >> "$report"
                continue
            fi

            target="chapter_${chapter_number}_${normalized}"
        fi

        if [[ "$name" == "$target" ]]; then
            printf 'No change needed.\n'
            printf 'No change needed.\n' >> "$report"
            continue
        fi

        unique_target=$(get_unique_path "$folder/$target")
        OLD_PATHS+=("$file")
        NEW_PATHS+=("$unique_target")
        PLANNED_TARGETS+=("$unique_target")
        printf 'Queued: %s -> %s\n' "$name" "$(basename "$unique_target")"
        printf 'Queued: %s -> %s\n' "$name" "$(basename "$unique_target")" >> "$report"
    done 3< <(find "$folder" -maxdepth 1 -type f ! -name "$PROGRAM_NAME" ! -name 'normalize_report_*.txt' -print0 2>/dev/null | sort -z)

    [[ ${#OLD_PATHS[@]} -gt 0 ]]
}

show_planned_renames() {
    local report i
    report=$1

    printf '\nPlanned renames:\n'
    printf '\nPlanned renames:\n' >> "$report"
    for i in "${!OLD_PATHS[@]}"; do
        printf '%s  ->  %s\n' "$(basename "${OLD_PATHS[$i]}")" "$(basename "${NEW_PATHS[$i]}")"
        printf '%s  ->  %s\n' "$(basename "${OLD_PATHS[$i]}")" "$(basename "${NEW_PATHS[$i]}")" >> "$report"
    done
}

apply_renames() {
    local report i
    report=$1

    for i in "${!OLD_PATHS[@]}"; do
        if mv -- "${OLD_PATHS[$i]}" "${NEW_PATHS[$i]}"; then
            printf 'Renamed: %s\n' "$(basename "${NEW_PATHS[$i]}")" >> "$report"
        else
            printf 'Failed: %s\n' "$(basename "${OLD_PATHS[$i]}")" >> "$report"
            return 1
        fi
    done

    return 0
}

main() {
    local mode folder report file_count confirm

    if [[ $# -lt 1 || $# -gt 2 ]]; then
        usage
        exit 2
    fi

    mode=$1
    folder=${2:-.}

    case "$mode" in
        preview|apply|stats)
            ;;
        *)
            usage
            exit 2
            ;;
    esac

    if ! is_directory "$folder"; then
        printf 'Invalid folder path: %s\n' "$folder" >&2
        exit 1
    fi

    if ! command_exists find || ! command_exists sed || ! command_exists sort || ! command_exists uniq || ! command_exists tee; then
        printf 'Required command-line tools are missing.\n' >&2
        exit 1
    fi

    file_count=$(count_files "$folder")
    if [[ "$file_count" -eq 0 ]]; then
        printf 'No files found.\n'
        exit 0
    fi

    report=$(make_report_path "$folder")
    : > "$report"

    if [[ "$mode" == "stats" ]]; then
        print_stats "$folder" "$report"
        printf '\nReport written to: %s\n' "$report"
        exit 0
    fi

    printf 'Mode: %s\nFolder: %s\nFiles found: %s\nReport: %s\n' "$mode" "$folder" "$file_count" "$report"
    printf 'Mode: %s\nFolder: %s\nFiles found: %s\nReport: %s\n' "$mode" "$folder" "$file_count" "$report" >> "$report"

    if ! collect_renames "$mode" "$folder" "$report"; then
        printf '\nNo files were queued for renaming.\n'
        printf '\nNo files were queued for renaming.\n' >> "$report"
        exit 0
    fi

    show_planned_renames "$report"

    if [[ "$mode" == "preview" ]]; then
        printf '\nPreview complete. No files were renamed.\n'
        printf '\nPreview complete. No files were renamed.\n' >> "$report"
        printf 'Report written to: %s\n' "$report"
        exit 0
    fi

    printf '\nApply these changes? (y/n): '
    IFS= read -r confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        printf 'Rename cancelled.\n'
        printf 'Rename cancelled.\n' >> "$report"
        exit 0
    fi

    if apply_renames "$report"; then
        printf '\nRenamed %s file(s).\n' "${#OLD_PATHS[@]}"
        printf '\nRenamed %s file(s).\n' "${#OLD_PATHS[@]}" >> "$report"
        printf 'Report written to: %s\n' "$report"
        exit 0
    fi

    printf 'One or more renames failed. See report: %s\n' "$report" >&2
    exit 1
}

main "$@"
