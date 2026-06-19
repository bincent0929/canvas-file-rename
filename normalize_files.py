#!/usr/bin/env python3
from pathlib import Path
import re
import wordninja


CHAPTER_PREFIX_RE = re.compile(r"^(chapter_\d+_)", re.IGNORECASE)


def smart_word_split(text: str) -> str:
    """
    Use wordninja to split merged English words, then join them with underscores.

    Example:
    ThinkingaboutChildDevelopment
    -> Thinking_about_Child_Development
    """
    if not text:
        return text

    words = wordninja.split(text)
    return "_".join(words)


def normalize_body(stem: str) -> str:
    """
    Clean the filename body while preserving readable underscores.
    """
    # Remove Canvas "-Tagged" suffix if present
    stem = re.sub(r"-Tagged$", "", stem, flags=re.IGNORECASE)

    # Remove parenthesized numbers like (1), (2), (23)
    stem = re.sub(r"\(\d+\)", "", stem)

    # Remove trailing copy markers like -1 before -Tagged or extension
    # Example: GeneticsandPrenatalDevelopment-1 -> GeneticsandPrenatalDevelopment
    stem = re.sub(r"-\d+$", "", stem)

    # Change & to "and"
    stem = stem.replace("&", " and ")

    # Remove commas
    stem = stem.replace(",", "")

    # Collapse multiple periods into one
    stem = re.sub(r"\.{2,}", ".", stem)

    # Add spaces before capital letters after lowercase letters
    # Example: ChildDevelopment -> Child Development
    # ?? Do I still want to have this when I'm using the wordninja library??
    stem = re.sub(r"(?<=[a-z])(?=[A-Z])", " ", stem)

    # Treat spaces, hyphens, and periods as separators
    parts = re.split(r"[\s\-.]+", stem)

    cleaned_parts = []

    for part in parts:
        part = part.strip("_")

        if not part:
            continue

        # Keep short chapter markers readable
        # Example: Ch5 -> Ch5
        if re.fullmatch(r"Ch\d+", part, flags=re.IGNORECASE):
            cleaned_parts.append(part)
            continue

        # Keep plain numbers as-is
        if part.isdigit():
            cleaned_parts.append(part)
            continue

        # Use wordninja for merged English words
        split_part = smart_word_split(part)
        cleaned_parts.append(split_part)

    cleaned_stem = "_".join(cleaned_parts)

    # Collapse repeated underscores
    cleaned_stem = re.sub(r"_+", "_", cleaned_stem)

    # Remove leading/trailing underscores
    cleaned_stem = cleaned_stem.strip("_")

    return cleaned_stem


def normalize_filename(name: str) -> str:
    """
    Clean Canvas-style filenames while preserving an existing chapter prefix.

    Examples:
    "ThinkingaboutChildDevelopmentCurrent&CulturalPerspectives(2)-Tagged.pdf"
    -> "Thinking_about_Child_Development_Current_and_Cultural_Perspectives.pdf"

    "chapter_4_Birthandthenewbornchild.(1)-Tagged.pdf"
    -> "chapter_4_Birth_and_the_newborn_child.pdf"
    """
    path = Path(name)

    stem = path.stem
    suffix = path.suffix

    chapter_prefix = ""

    match = CHAPTER_PREFIX_RE.match(stem)
    if match:
        chapter_prefix = match.group(1).lower()
        stem = stem[len(match.group(1)):]

    cleaned_stem = normalize_body(stem)

    return f"{chapter_prefix}{cleaned_stem}{suffix}"


def has_chapter_prefix(name: str) -> bool:
    return CHAPTER_PREFIX_RE.match(Path(name).stem) is not None


def get_unique_path(path: Path) -> Path:
    """
    Avoid overwriting existing files by adding _1, _2, etc.
    """
    if not path.exists():
        return path

    counter = 1
    while True:
        new_path = path.with_name(f"{path.stem}_{counter}{path.suffix}")
        if not new_path.exists():
            return new_path
        counter += 1


def main():
    folder_input = input("Enter folder path, or press Enter for current folder: ").strip()
    folder = Path(folder_input) if folder_input else Path.cwd() # cwd?

    if not folder.exists() or not folder.is_dir():
        print("Invalid folder path.")
        return

    script_path = Path(__file__).resolve()

    files = sorted(
        item for item in folder.iterdir()
        if item.is_file() and item.resolve() != script_path
    )

    if not files:
        print("No files found.")
        return

    preview_first = input("Preview all changes before renaming? (y/n): ").strip().lower() == "y"

    rename_pairs = []

    for file_path in files:
        print(f"\nFile: {file_path.name}")

        normalized_name = normalize_filename(file_path.name)

        if has_chapter_prefix(file_path.name):
            new_name = normalized_name
            print("Chapter prefix already found; not prompting for chapter number.")
        else:
            chapter_number = input(
                "Enter chapter number for this file, or press Enter to skip: "
            ).strip()

            if not chapter_number:
                print("Skipped.")
                continue

            new_name = f"chapter_{chapter_number}_{normalized_name}"

        new_path = get_unique_path(folder / new_name)

        if file_path.name != new_path.name:
            rename_pairs.append((file_path, new_path))
            print(f"Queued: {file_path.name} -> {new_path.name}")
        else:
            print("No change needed.")

    if not rename_pairs:
        print("\nNo files were queued for renaming.")
        return

    print("\nPlanned renames:")
    for old_path, new_path in rename_pairs:
        print(f"{old_path.name}  ->  {new_path.name}")

    if preview_first:
        confirm = input("\nApply these changes? (y/n): ").strip().lower()
        if confirm != "y":
            print("Rename cancelled.")
            return

    for old_path, new_path in rename_pairs:
        old_path.rename(new_path)

    print(f"\nRenamed {len(rename_pairs)} file(s).")


if __name__ == "__main__":
    main()
