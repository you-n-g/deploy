#!/bin/bash

# Get the absolute path of the current script's directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

CUSTOM_SKILLS_DIR="$SCRIPT_DIR/skills"
EXTERNAL_REPOS_DIR="$SCRIPT_DIR/external"
MERGED_SKILLS_DIR="$SCRIPT_DIR/merged-skills"
OBSIDIAN_SKILLS_DIR="$EXTERNAL_REPOS_DIR/obsidian-skills"

ensure_dirs() {
    mkdir -p "$CUSTOM_SKILLS_DIR"
    mkdir -p "$EXTERNAL_REPOS_DIR"
    mkdir -p "$MERGED_SKILLS_DIR"
}

# ── External repos ────────────────────────────────────────────────────────────

install_external_skills() {
    ensure_dirs

    if [ ! -d "$OBSIDIAN_SKILLS_DIR" ]; then
        echo "Cloning external skills from kepano/obsidian-skills..."
        git clone --depth 1 https://github.com/kepano/obsidian-skills "$OBSIDIAN_SKILLS_DIR"
    else
        echo "Updating external skills from kepano/obsidian-skills..."
        (cd "$OBSIDIAN_SKILLS_DIR" && git pull --ff-only)
    fi

    bash "$SCRIPT_DIR/install_rednote.sh"
    bash "$SCRIPT_DIR/install_excalidraw_diagram_skill.sh"
    # bash "$SCRIPT_DIR/install_x_research.sh"

    npm install -g defuddle-cli
}

# ── Merge: link every skill folder into merged-skills/ ───────────────────────

link_skill() {
    local skill_dir=$1
    local skill_name
    skill_name=$(basename "$skill_dir")
    # skip if SKILL.md is disabled
    [ -f "$skill_dir/SKILL.md" ] || return 0
    ln -snf "$skill_dir" "$MERGED_SKILLS_DIR/$skill_name"
}

merge_skills() {
    ensure_dirs

    # Custom skills
    for skill in "$CUSTOM_SKILLS_DIR"/*/; do
        [ -d "$skill" ] && link_skill "$skill"
    done

    # External repos with a root-level SKILL.md
    for skill in "$EXTERNAL_REPOS_DIR"/*; do
        [ -d "$skill" ] && link_skill "$skill"
    done

    # External: obsidian-skills
    if [ -d "$OBSIDIAN_SKILLS_DIR/skills" ]; then
        for skill in "$OBSIDIAN_SKILLS_DIR/skills"/*/; do
            [ -d "$skill" ] && link_skill "$skill"
        done
    fi

    # Farside skills
    FARSIDE_SKILLS_DIR="$HOME/farside/llm/skills"
    if [ -d "$FARSIDE_SKILLS_DIR" ]; then
        for skill in "$FARSIDE_SKILLS_DIR"/*/; do
            [ -d "$skill" ] && link_skill "$skill"
        done
    fi

    echo "Merged skills: $(ls "$MERGED_SKILLS_DIR" | wc -l) skills linked."
}

# ── Environment-based skill exclusions ───────────────────────────────────────

_can_run_containers() {
    case "$(uname)" in
        Darwin) return 0 ;;       # macOS: assume Docker Desktop can be installed
        *)  test -w /sys/fs/cgroup ;;
    esac
}

disable_skill() {
    local name=$1
    if [ -L "$MERGED_SKILLS_DIR/$name" ]; then
        rm "$MERGED_SKILLS_DIR/$name"
        echo "Disabled skill: $name"
    fi
}

apply_skill_exclusions() {
    ensure_dirs

    if [ "$(uname)" != "Darwin" ]; then
        echo "Not macOS, disabling Obsidian skills..."
        for s in "$MERGED_SKILLS_DIR"/obsidian-*; do
            [ -L "$s" ] && disable_skill "$(basename "$s")"
        done

        disable_skill "excalidraw-diagram-skill"
    fi

    if ! _can_run_containers; then
        echo "No container runtime, disabling container-dependent skills..."
        disable_skill "cr"
    else
        disable_skill "defuddle"
    fi

    echo "Active skills: $(ls "$MERGED_SKILLS_DIR" | wc -l)"
}

# ── Link merged-skills/ to each agent ────────────────────────────────────────

link_skills_for_tool() {
    local tool_name=$1
    local target_dir="$HOME/.$tool_name/skills"
    mkdir -p "$HOME/.$tool_name"

    if [ -d "$target_dir" ] && ! [ -L "$target_dir" ]; then
        echo "WARNING: '$target_dir' exists as a real directory. Replacing with symlink..."
        rm -rf "$target_dir"
    elif [ -L "$target_dir" ]; then
        local current_target
        current_target=$(readlink "$target_dir")
        if [ "$current_target" = "$MERGED_SKILLS_DIR" ]; then
            echo "Info: '$target_dir' already correctly linked."
            return 0
        fi
        rm "$target_dir"
    fi

    ln -s "$MERGED_SKILLS_DIR" "$target_dir"
    echo "Linked: $target_dir -> $MERGED_SKILLS_DIR"
}

link_all_skills() {
    ensure_dirs
    link_skills_for_tool "gemini"
    link_skills_for_tool "codex"
    link_skills_for_tool "claude"
    echo "Skills linking complete."
}

# ── Install agents ────────────────────────────────────────────────────────────

# ── Deploy default .sgpt.md to home directory ────────────────────────────────
deploy_sgpt_prompt() {
    ln -snf "$SCRIPT_DIR/.sgpt.md" "$HOME/.sgpt.md"
    echo "Linked: ~/.sgpt.md -> $SCRIPT_DIR/.sgpt.md"
}

# ── Deploy global CLAUDE.md to ~/.claude/CLAUDE.md ───────────────────────────
deploy_claude_prompt() {
    mkdir -p "$HOME/.claude"
    ln -snf "$SCRIPT_DIR/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
    echo "Linked: ~/.claude/CLAUDE.md -> $SCRIPT_DIR/CLAUDE.md"
}

# ── Deploy global AGENTS.md to ~/.codex/AGENTS.md ───────────────────────────
deploy_codex_agents() {
    mkdir -p "$HOME/.codex"
    ln -snf "$SCRIPT_DIR/CLAUDE.md" "$HOME/.codex/AGENTS.md"
    echo "Linked: ~/.codex/AGENTS.md -> $SCRIPT_DIR/CLAUDE.md"
}

deploy_prompts() {
    deploy_sgpt_prompt
    deploy_claude_prompt
    deploy_codex_agents
}

install_agents() {
    command -v gemini &>/dev/null || npm install -g @google/gemini-cli
    command -v codex  &>/dev/null || npm install -g @openai/codex
    command -v claude &>/dev/null || curl -fsSL https://claude.ai/install.sh | bash
    # ~/deploy/deploy_apps/config_codex.py  # The latest usage of codex depends on login now
}

# 🙌🏻 得手动一次输入下面的命令
# https://github.com/jarrodwatts/claude-hud
# 注意得完成setup会生效：
print_claude_hud_instructions() {
    cat << "EOF"
clauder
/plugin marketplace add jarrodwatts/claude-hud
/plugin install claude-hud
/reload-plugins
/claude-hud:setup
/claude-hud:setup
EOF
}

run_all() {
    install_external_skills
    merge_skills
    apply_skill_exclusions
    link_all_skills
    deploy_prompts
    install_agents
}

print_usage() {
    cat << EOF
Usage: $(basename "$0") [command ...]

Commands:
  all              Run the full setup. This is the default when no command is given.
  external-skills  Clone/update external skill repos and install skill CLIs.
  merge-skills     Link custom/external/Farside skills into merged-skills/.
  skill-exclusions Disable skills that do not apply to this environment.
  link-skills      Link merged-skills/ into ~/.gemini, ~/.codex, and ~/.claude.
  skills           Run external-skills, merge-skills, skill-exclusions, and link-skills.
  prompts          Link .sgpt.md, Claude CLAUDE.md, and Codex AGENTS.md.
  codex-agents     Link only ~/.codex/AGENTS.md.
  claude-prompt    Link only ~/.claude/CLAUDE.md.
  sgpt-prompt      Link only ~/.sgpt.md.
  install-agents   Install gemini, codex, and claude CLIs if missing.
  claude-hud       Print the manual claude-hud setup commands.
  help             Show this help.
EOF
}

run_command() {
    case "$1" in
        all) run_all ;;
        external-skills) install_external_skills ;;
        merge-skills) merge_skills ;;
        skill-exclusions) apply_skill_exclusions ;;
        link-skills) link_all_skills ;;
        skills)
            install_external_skills
            merge_skills
            apply_skill_exclusions
            link_all_skills
            ;;
        prompts) deploy_prompts ;;
        codex-agents) deploy_codex_agents ;;
        claude-prompt) deploy_claude_prompt ;;
        sgpt-prompt) deploy_sgpt_prompt ;;
        install-agents) install_agents ;;
        claude-hud) print_claude_hud_instructions ;;
        help|-h|--help) print_usage ;;
        *)
            echo "Unknown command: $1" >&2
            print_usage >&2
            return 1
            ;;
    esac
}

if [ "$#" -eq 0 ]; then
    run_all
else
    for command in "$@"; do
        run_command "$command" || exit $?
    done
fi
