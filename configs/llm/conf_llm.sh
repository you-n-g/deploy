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

# Function to link skills directory for a specific tool
link_skills_for_tool() {
    local tool_name=$1
    local target_dir="$HOME/.$tool_name/skills"
    local tool_config_dir="$HOME/.$tool_name"

    echo "Configuring skills for $tool_name..."
    mkdir -p "$tool_config_dir"
    # Handle existing target_dir states:
    # - If it's a real directory, automatically replace it with a symlink
    # - If it's a symlink but points elsewhere, replace it
    # - If it's already correctly linked, skip
    if [ -d "$target_dir" ] && ! [ -L "$target_dir" ]; then
        echo "WARNING: '$target_dir' exists as a directory. Replacing it with a symlink..."
        rm -rf "$target_dir"
    elif [ -L "$target_dir" ]; then
        local current_target=$(readlink "$target_dir")
        if [ "$current_target" = "$SOURCE_CUSTOM_SKILLS_BASE_DIR" ]; then
            echo "Info: '$target_dir' is already correctly linked."
            return 0
        fi
        echo "Updating symlink: '$target_dir' (old target: $current_target)"
        rm "$target_dir"
    fi

    echo "Creating symbolic link: '$target_dir' -> '$SOURCE_CUSTOM_SKILLS_BASE_DIR'"
    ln -s "$SOURCE_CUSTOM_SKILLS_BASE_DIR" "$target_dir"
}

# Link for both gemini and codex
link_skills_for_tool "gemini"
link_skills_for_tool "codex"
echo "Skills linking process complete for all AI tools."

npm install -g @google/gemini-cli
npm install -g @openai/codex
~/deploy/deploy_apps/config_codex.py
