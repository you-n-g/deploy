#!/bin/bash

# Get the absolute path of the current script's directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Source directory containing ALL your custom skills
SOURCE_CUSTOM_SKILLS_BASE_DIR="$SCRIPT_DIR/skills"
EXTERNAL_REPOS_DIR="$SCRIPT_DIR/external"

mkdir -p "$SOURCE_CUSTOM_SKILLS_BASE_DIR"
mkdir -p "$EXTERNAL_REPOS_DIR"

# Manage external skills (kepano/obsidian-skills)
OBSIDIAN_SKILLS_DIR="$EXTERNAL_REPOS_DIR/obsidian-skills"
if [ ! -d "$OBSIDIAN_SKILLS_DIR" ]; then
    echo "Cloning external skills from kepano/obsidian-skills..."
    git clone --depth 1 https://github.com/kepano/obsidian-skills "$OBSIDIAN_SKILLS_DIR"
else
    echo "Updating external skills from kepano/obsidian-skills..."
    (cd "$OBSIDIAN_SKILLS_DIR" && git pull)
fi

# Link skills from external repo to SOURCE_CUSTOM_SKILLS_BASE_DIR
if [ -d "$OBSIDIAN_SKILLS_DIR/skills" ]; then
    echo "Linking external skills..."
    for skill in "$OBSIDIAN_SKILLS_DIR/skills"/*; do
        if [ -d "$skill" ]; then
            skill_name=$(basename "$skill")
            ln -snf "$skill" "$SOURCE_CUSTOM_SKILLS_BASE_DIR/$skill_name"
        fi
    done
fi

# Target directory where gemini is expected to find skills.
# The user explicitly requested to link the *entire* source folder directly here.
TARGET_GEMINI_SKILLS_DIR="$HOME/.gemini/skills"

# Check if TARGET_GEMINI_SKILLS_DIR already exists
if [ -d "$TARGET_GEMINI_SKILLS_DIR" ] && ! [ -L "$TARGET_GEMINI_SKILLS_DIR" ]; then
    echo "ERROR: '$TARGET_GEMINI_SKILLS_DIR' exists and is a directory (not a symlink)."
    echo "       Linking the entire folder here will effectively replace this directory with a symlink."
    echo "       Please manually remove or rename '$TARGET_GEMINI_SKILLS_DIR' if you wish to proceed with this linking strategy."
    exit 1
elif [ -L "$TARGET_GEMINI_SKILLS_DIR" ]; then
    # If it's already a symlink, check where it points
    current_target=$(readlink "$TARGET_GEMINI_SKILLS_DIR")
    if [ "$current_target" = "$SOURCE_CUSTOM_SKILLS_BASE_DIR" ]; then
        echo "Info: '$TARGET_GEMINI_SKILLS_DIR' is already a symlink pointing to the correct source. No action needed."
        exit 0
    else
        echo "Warning: '$TARGET_GEMINI_SKILLS_DIR' is already a symlink, but points to '$current_target'."
        echo "         Removing old symlink and creating a new one to '$SOURCE_CUSTOM_SKILLS_BASE_DIR'."
        rm "$TARGET_GEMINI_SKILLS_DIR"
    fi
fi

# Create the symbolic link
echo "Creating symbolic link from '$SOURCE_CUSTOM_SKILLS_BASE_DIR' to '$TARGET_GEMINI_SKILLS_DIR'."
ln -s "$SOURCE_CUSTOM_SKILLS_BASE_DIR" "$TARGET_GEMINI_SKILLS_DIR"

echo "Entire skills folder linking process complete. '$TARGET_GEMINI_SKILLS_DIR' is now a symlink to your custom skills folder."
