#!/usr/bin/env bash

PROGRAM_NAME=$(basename "$0")
PLANNED_TARGETS=()

# Print command usage, supported modes, and exit code meanings.
usage() {
    cat <<USAGE
Usage:
  $PROGRAM_NAME preview [folder]
  $PROGRAM_NAME apply [folder]
  $PROGRAM_NAME stats [folder]

Modes:
  preview   Show proposed normalized filenames without copying files
  apply     Show proposed filenames, confirm, then copy files into normalized/
  stats     Summarize filename patterns in the folder

Exit codes:
  0  success
  1  failure
  2  incorrect usage
USAGE
}

# Return success when the given path is a directory.
is_directory() {
    [[ -d "$1" ]]
}

# Return success when the named command is available on the system.
# It basically returns a boolean value for whether
# the command exists
command_exists() {
    # command checks whether the giving command exists
    # >/dev/null discards the normal output
    # 2>&1 discards the error output
    command -v "$1" >/dev/null 2>&1
}

# Remove trailing slashes from a folder path while preserving root.
normalize_folder_path() {
    local path
    path=$1

    # makes sure it isn't root
    # makes sure that there are still `/` to remove
    while [[ "$path" != "/" && "$path" == */ ]]; do
        # removes a `/` from the path
        path=${path%/}
    done # no more `/` in the path's string

    printf '%s\n' "$path"
}

# Return success when a filename already starts with chapter_N_.
has_chapter_prefix() {
    local name stem
    # this removes the folder path
    # jim/bean.md -> bean.md
    name=$(basename "$1")
    # removes the file extension
    stem=${name%.*}
    [[ "$stem" =~ ^[Cc][Hh][Aa][Pp][Tt][Ee][Rr]_[0-9]+_ ]]
}

# Return success when a target path has already been planned in this run.
path_is_planned() {
    local candidate planned
    candidate=$1
    # checks the planned targets whether
    # they are the same as the candidate
    # aka whether the candidate has been planned
    for planned in "${PLANNED_TARGETS[@]}"; do
        [[ "$planned" == "$candidate" ]] && return 0
    done
    return 1
}

# Print the number of regular source files in the folder.
count_files() {
    # looks in the folder for files
    # doesn't search subfolders
    # only counts regular files
    # doesn't count the bash program itself
    # doesn't count the generated report
    # prints the filesnames and discards errors from the find
    # the total files are then counted and spaces are removed from their lines
    find "$1" -maxdepth 1 -type f ! -name "$PROGRAM_NAME" ! -name 'normalize_report_*.txt' -print 2>/dev/null | wc -l | tr -d ' '
}

# Print a timestamped report path inside the given folder.
make_report_path() {
    local folder stamp
    folder=$1
    stamp=$(date '+%Y%m%d_%H%M%S')
    # constructs the report path
    # the final string is the process ID and prevents same-second conflicts
    printf '%s/normalize_report_%s_%s.txt\n' "$folder" "$stamp" "$$"
}

# Split merged words using wordninja when available, with a local fallback.
smart_word_split() {
    local text
    text=$1

    # checks whether the text is empty
    if [[ -z "$text" ]]; then
        printf '\n'
        return 0
    fi

    # if there is text,
    # the program tries to run the Python script that
    # uses wordninja to smart split the words for cleaner
    # paths
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

# Clean the filename stem by removing download markers and normalizing words.
normalize_body() {
    local stem cleaned part split_part cleaned_parts
    stem=$1
    cleaned_parts=() # an array

    # removed "-Tagged"
    stem=$(printf '%s' "$stem" | sed -E 's/-[Tt][Aa][Gg][Gg][Ee][Dd]$//')
    # removes (N) with N being an integer
    stem=$(printf '%s' "$stem" | sed -E 's/\([0-9]+\)//g')
    # removes -N with N being an integer
    stem=$(printf '%s' "$stem" | sed -E 's/-[0-9]+$//')
    # changes "&" to "and"
    # removes commas
    # changes "..." to "."
    stem=$(printf '%s' "$stem" | sed -E 's/&/ and /g; s/,//g; s/\.{2,}/./g')
    # this is for the next two:
    # removes previous chapter markers from the beginning
    # for example, "Slides 6.11 Ch 6" and "Ch 5"
    stem=$(printf '%s' "$stem" | sed -E 's/^[Ss]lides[[:space:]]+[0-9]+(\.[0-9]+)*[[:space:]]+[Cc][Hh][[:space:]]*[0-9]+[[:space:]]+//')
    stem=$(printf '%s' "$stem" | sed -E 's/^[Cc][Hh][[:space:]]*[0-9]+[[:space:]]+//')
    # adds spaces between lowercase and uppercase letters
    # aka separates words based on capitals (supplemented by the smart splitting seen in smart_word_split)
    stem=$(printf '%s' "$stem" | sed -E 's/([[:lower:]])([[:upper:]])/\1 \2/g')

    # The loop takes the `stem` which has been
    # processed to a great extent and further refines it.
    # It takes each word from the stem and
    # separates them by newlines 
    # (changes spaces, periods, and hyphens into newlines).
    while IFS= read -r part; do
        # this removes underscores from the 
        # beginning and end of the word line
        part=$(printf '%s' "$part" | sed -E 's/^_+//; s/_+$//')
        
        # continues if the line isn't empty
        [[ -z "$part" ]] && continue

        # if the line has something like "Ch5"
        # then it doesn't change the line.
        if [[ "$part" =~ ^[Cc][Hh][0-9]+$ ]]; then
            cleaned_parts+=("$part")
            continue
        fi

        # if the line is a number
        # then it doesn't change it.
        if [[ "$part" =~ ^[0-9]+$ ]]; then
            cleaned_parts+=("$part")
            continue
        fi

        # feeds the line into the smart python splitter
        # and it separates any combined words.
        split_part=$(smart_word_split "$part")
        cleaned_parts+=("$split_part")
    done < <(printf '%s\n' "$stem" | tr '[:space:].-' '\n') # the loop reads from this line

    # joins the words the the array using "_"
    cleaned=$(IFS=_; printf '%s' "${cleaned_parts[*]}")
    # fixes repeated underscores,
    # removes leading underscores,
    # and removes trailing underscores.
    cleaned=$(printf '%s' "$cleaned" | sed -E 's/_+/_/g; s/^_+//; s/_+$//')
    printf '%s\n' "$cleaned"
}

# Print the normalized filename while preserving the file extension.
normalize_filename() {
    local name stem suffix prefix cleaned
    # grabs the filename from the input and removes the path
    name=$(basename "$1")
    suffix=""
    
    # separates the "stem" or 
    # file extension excluding porition
    # from the file extension
    if [[ "$name" == *.* && "$name" != .* ]]; then
        suffix=".${name##*.}"
        stem=${name%.*}
    else
        stem=$name
    fi

    # separates the stem from the standard prefix
    # for chaptering as defined in the extension
    # ex. "chapter_N" with N being an integer
    prefix=""
    if [[ "$stem" =~ ^([Cc][Hh][Aa][Pp][Tt][Ee][Rr]_[0-9]+_) ]]; then
        prefix=$(printf '%s' "${BASH_REMATCH[1]}" | tr '[:upper:]' '[:lower:]')
        stem=${stem:${#BASH_REMATCH[1]}}
    fi

    # this feeds the stem into the normalizer
    # see the function above for specification
    cleaned=$(normalize_body "$stem")
    # re-adds the prefix and suffix to the filename
    printf '%s%s%s\n' "$prefix" "$cleaned" "$suffix"
}

# Print a non-conflicting target path by adding numeric suffixes as needed.
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

# Print the chapter number found in a normalized filename, or a high fallback.
get_chapter_number() {
    local name
    name=$(basename "$1")

    if [[ "$name" =~ ^[Cc][Hh][Aa][Pp][Tt][Ee][Rr]_([0-9]+)_ ]]; then
        printf '%s\n' "${BASH_REMATCH[1]}"
        return 0
    fi

    printf '999999\n'
}

# Print one formatted source-to-target copy line with its chapter label.
print_copy_line() {
    local old_path new_path chapter_number
    old_path=$1
    new_path=$2
    chapter_number=$(get_chapter_number "$new_path")

    if [[ "$chapter_number" == "999999" ]]; then
        printf 'Chapter unknown: %s  ->  normalized/%s\n' "$(basename "$old_path")" "$(basename "$new_path")"
    else
        printf 'Chapter %s: %s  ->  normalized/%s\n' "$((10#$chapter_number))" "$(basename "$old_path")" "$(basename "$new_path")"
    fi
}

# Sort the planned copy arrays by chapter number.
sort_planned_copies() {
    local count i j old_path new_path current_chapter next_chapter
    count=${#OLD_PATHS[@]}

    for ((i = 0; i < count; i++)); do
        for ((j = i + 1; j < count; j++)); do
            current_chapter=$(get_chapter_number "${NEW_PATHS[$i]}")
            next_chapter=$(get_chapter_number "${NEW_PATHS[$j]}")

            if ((10#$next_chapter < 10#$current_chapter)); then
                old_path=${OLD_PATHS[$i]}
                new_path=${NEW_PATHS[$i]}

                OLD_PATHS[$i]=${OLD_PATHS[$j]}
                NEW_PATHS[$i]=${NEW_PATHS[$j]}

                OLD_PATHS[$j]=$old_path
                NEW_PATHS[$j]=$new_path
            fi
        done
    done
}

# Print filename statistics to the terminal.
print_stats() {
    local folder total chapter_count tagged_count duplicate_stems
    folder=$1

    total=$(count_files "$folder")
    chapter_count=$(find "$folder" -maxdepth 1 -type f ! -name 'normalize_report_*.txt' -printf '%f\n' 2>/dev/null | grep -Eic '^chapter_[0-9]+_')
    tagged_count=$(find "$folder" -maxdepth 1 -type f ! -name 'normalize_report_*.txt' -printf '%f\n' 2>/dev/null | grep -Eic -- '-Tagged\.')
    duplicate_stems=$(find "$folder" -maxdepth 1 -type f ! -name 'normalize_report_*.txt' -printf '%f\n' 2>/dev/null | sed -E 's/\.[^.]+$//' | sort | uniq -d | wc -l | tr -d ' ')

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
}

# Print the newest preview report path from the normalized folder.
find_latest_preview_report() {
    local output_dir candidate latest first_line
    output_dir=$1
    latest=""

    for candidate in "$output_dir"/normalize_report_*.txt; do
        [[ -f "$candidate" ]] || continue
        IFS= read -r first_line < "$candidate"
        if [[ "$first_line" == "Mode: preview" ]]; then
            latest=$candidate
        fi
    done

    [[ -n "$latest" ]] || return 1
    printf '%s\n' "$latest"
}

# Load planned copy paths from an existing preview report.
load_preview_plan() {
    local folder output_dir preview_report line in_plan old_name new_name
    folder=$1
    output_dir=$2
    preview_report=$3

    OLD_PATHS=()
    NEW_PATHS=()
    PLANNED_TARGETS=()
    in_plan=0

    while IFS= read -r line; do
        if [[ "$line" == "Planned copies:" ]]; then
            in_plan=1
            continue
        fi

        if [[ "$in_plan" -eq 1 && -z "$line" ]]; then
            break
        fi

        if [[ "$in_plan" -eq 1 && "$line" =~ ^Chapter\ ([0-9]+|unknown):\ (.*)\ \ -\>\ \ normalized/(.*)$ ]]; then
            old_name=${BASH_REMATCH[2]}
            new_name=${BASH_REMATCH[3]}

            if [[ ! -f "$folder/$old_name" ]]; then
                printf 'Preview plan references a missing file: %s\n' "$old_name" >&2
                return 1
            fi

            OLD_PATHS+=("$folder/$old_name")
            NEW_PATHS+=("$output_dir/$new_name")
            PLANNED_TARGETS+=("$output_dir/$new_name")
        fi
    done < "$preview_report"

    [[ ${#OLD_PATHS[@]} -gt 0 ]]
}

# Build the list of planned copies, prompting for chapter numbers when needed.
collect_copies() {
    local mode folder report output_dir file name normalized chapter_number target target_path unique_target
    mode=$1
    folder=$2
    report=$3
    output_dir=$4

    OLD_PATHS=()
    NEW_PATHS=()
    PLANNED_TARGETS=()

    while IFS= read -r -d '' -u 3 file; do
        name=$(basename "$file")
        printf '\nFile: %s\n' "$name"

        normalized=$(normalize_filename "$name")

        if has_chapter_prefix "$name"; then
            target=$normalized
            printf 'Chapter prefix already found; not prompting for chapter number.\n'
        else
            printf 'Enter chapter number for this file, or press Enter to skip: '
            IFS= read -r chapter_number

            if [[ -z "$chapter_number" ]]; then
                printf 'Skipped.\n'
                continue
            fi

            if [[ ! "$chapter_number" =~ ^[0-9]+$ ]]; then
                printf 'Invalid chapter number; skipped.\n'
                continue
            fi

            target="chapter_${chapter_number}_${normalized}"
        fi

        target_path="$output_dir/$target"
        unique_target=$(get_unique_path "$target_path")
        OLD_PATHS+=("$file")
        NEW_PATHS+=("$unique_target")
        PLANNED_TARGETS+=("$unique_target")
        printf 'Queued: %s -> normalized/%s\n' "$name" "$(basename "$unique_target")"
    done 3< <(find "$folder" -maxdepth 1 -type f ! -name "$PROGRAM_NAME" ! -name 'normalize_report_*.txt' -print0 2>/dev/null | sort -z)

    [[ ${#OLD_PATHS[@]} -gt 0 ]]
}

# Print the planned copies to the terminal and report.
show_planned_copies() {
    local report i
    report=$1

    printf '\nPlanned copies:\n'
    printf '\nPlanned copies:\n' >> "$report"
    for i in "${!OLD_PATHS[@]}"; do
        print_copy_line "${OLD_PATHS[$i]}" "${NEW_PATHS[$i]}"
        print_copy_line "${OLD_PATHS[$i]}" "${NEW_PATHS[$i]}" >> "$report"
    done
}

# Copy planned files into the normalized folder and log the results.
apply_copies() {
    local report output_dir i
    report=$1
    output_dir=$2

    if ! mkdir -p -- "$output_dir"; then
        printf 'Failed to create output directory: %s\n' "$output_dir" >> "$report"
        return 1
    fi

    printf '\nCopied files:\n' >> "$report"
    for i in "${!OLD_PATHS[@]}"; do
        if cp -- "${OLD_PATHS[$i]}" "${NEW_PATHS[$i]}"; then
            print_copy_line "${OLD_PATHS[$i]}" "${NEW_PATHS[$i]}" >> "$report"
        else
            printf 'Failed: %s\n' "$(basename "${OLD_PATHS[$i]}")" >> "$report"
            return 1
        fi
    done

    return 0
}

# Validate arguments, route modes, and control script exit status.
main() {
    local mode folder output_dir report file_count confirm preview_report

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

    folder=$(normalize_folder_path "$folder")
    output_dir="$folder/normalized"

    if ! command_exists find || ! command_exists sed || ! command_exists sort || ! command_exists uniq; then
        printf 'Required command-line tools are missing.\n' >&2
        exit 1
    fi

    file_count=$(count_files "$folder")
    if [[ "$file_count" -eq 0 ]]; then
        printf 'No files found.\n'
        exit 0
    fi

    if [[ "$mode" == "stats" ]]; then
        print_stats "$folder"
        exit 0
    fi

    if ! command_exists mkdir || ! command_exists cp; then
        printf 'Required command-line tools are missing.\n' >&2
        exit 1
    fi

    if ! mkdir -p -- "$output_dir"; then
        printf 'Failed to create output directory: %s\n' "$output_dir" >&2
        exit 1
    fi

    if [[ "$mode" == "apply" ]] && preview_report=$(find_latest_preview_report "$output_dir"); then
        report=$preview_report

        if ! load_preview_plan "$folder" "$output_dir" "$preview_report"; then
            printf 'Could not load planned copies from preview report: %s\n' "$preview_report" >&2
            printf '\nCould not load planned copies from preview report: %s\n' "$preview_report" >> "$report"
            exit 1
        fi

        printf '\n' >> "$report"
        printf 'Mode: %s\nFolder: %s\nFiles found: %s\nReport: %s\n' "$mode" "$folder" "$file_count" "$report"
        printf 'Mode: %s\nFolder: %s\nFiles found: %s\nReport: %s\n' "$mode" "$folder" "$file_count" "$report" >> "$report"
        printf 'Using preview report: %s\n' "$preview_report"
        printf 'Using preview report: %s\n' "$preview_report" >> "$report"
    else
        report=$(make_report_path "$output_dir")
        : > "$report"

        printf 'Mode: %s\nFolder: %s\nFiles found: %s\nReport: %s\n' "$mode" "$folder" "$file_count" "$report"
        printf 'Mode: %s\nFolder: %s\nFiles found: %s\nReport: %s\n' "$mode" "$folder" "$file_count" "$report" >> "$report"

        if ! collect_copies "$mode" "$folder" "$report" "$output_dir"; then
            printf '\nNo files were queued for copying.\n'
            printf '\nNo files were queued for copying.\n' >> "$report"
            exit 0
        fi
    fi

    sort_planned_copies
    show_planned_copies "$report"

    if [[ "$mode" == "preview" ]]; then
        printf '\nPreview complete. No files were copied.\n'
        printf '\nPreview complete. No files were copied.\n' >> "$report"
        printf 'Report written to: %s\n' "$report"
        exit 0
    fi

    printf '\nApply these changes and copy files into normalized/? (y/n): '
    IFS= read -r confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        printf 'Copy cancelled.\n'
        printf 'Copy cancelled.\n' >> "$report"
        exit 0
    fi

    if apply_copies "$report" "$output_dir"; then
        printf '\nCopied %s file(s) into: %s\n' "${#OLD_PATHS[@]}" "$output_dir"
        printf '\nCopied %s file(s) into: %s\n' "${#OLD_PATHS[@]}" "$output_dir" >> "$report"
        printf 'Report written to: %s\n' "$report"
        exit 0
    fi

    printf 'One or more copies failed. See report: %s\n' "$report" >&2
    exit 1
}

main "$@"
