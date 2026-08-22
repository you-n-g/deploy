#!/usr/bin/env bash
# Claude Code statusline modeled on the user's powerlevel10k prompt
# (~/deploy/configs/shell/p10k.zsh), whose visible segments are:
#   left:  dir, vcs (git status), prompt_char
#   right: time (most other right-side segments are conditional/rarely shown)
#
# Renders: <dir> <git-branch [+staged !unstaged ?untracked]>  <time>
# using the same color numbers as the p10k config.
#
# Git calls pass --no-optional-locks so they never block on a repo lock held
# by another process (e.g. another agent running in the same worktree), and
# the whole vcs segment comes from a single `status --porcelain --branch`
# rather than one subprocess per counter.

set -u

RESET=$'\e[0m'
DIR_FG=$'\e[38;5;31m'                 # POWERLEVEL9K_DIR_FOREGROUND
GIT_CLEAN_FG=$'\e[38;5;76m'           # POWERLEVEL9K_VCS_CLEAN_FOREGROUND
GIT_MODIFIED_FG=$'\e[38;5;178m'       # POWERLEVEL9K_VCS_MODIFIED_FOREGROUND
GIT_UNTRACKED_FG=$'\e[38;5;39m'       # POWERLEVEL9K_VCS_UNTRACKED_FOREGROUND
TIME_FG=$'\e[38;5;66m'                # POWERLEVEL9K_TIME_FOREGROUND
MODEL_FG=$'\e[38;5;141m'              # not a p10k segment; added for model/effort display

input="$(cat)"

cwd="$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd')"
if [ -z "$cwd" ] || [ "$cwd" = "null" ]; then
    echo "statusline-command: no cwd in stdin JSON" >&2
    exit 1
fi

# ---- dir segment: anchor at the git root (like p10k's .git anchor file) ----
dir_display="$cwd"
# --show-prefix rather than subtracting the root from $cwd: the two disagree
# whenever cwd reaches the repo through a symlink (/home/xiyang/deploy vs its
# /physical/lustre/... realpath), and git already knows the answer.
git_info="$(git -C "$cwd" --no-optional-locks rev-parse --show-toplevel --show-prefix 2>/dev/null)"
if [ -n "$git_info" ]; then
    git_root="${git_info%%$'\n'*}"
    # At the repo root the prefix line is empty, so command substitution
    # strips it and git_info is just the toplevel.
    if [ "$git_info" = "$git_root" ]; then rel=""; else rel="${git_info#*$'\n'}"; fi
    dir_display="$(basename "$git_root")${rel:+/${rel%/}}"
else
    git_root=""
    case "$dir_display" in
        "$HOME") dir_display="~" ;;
        "$HOME"/*) dir_display="~${dir_display#"$HOME"}" ;;
    esac
fi

# Shorten long paths: keep only the first character of intermediate
# segments, like p10k's truncate_to_unique strategy (approximated).
if [ "${#dir_display}" -gt 50 ]; then
    IFS='/' read -ra parts <<< "$dir_display"
    n="${#parts[@]}"
    short=""
    for i in "${!parts[@]}"; do
        seg="${parts[$i]}"
        [ -z "$seg" ] && continue
        if [ "$i" -ge $((n - 2)) ]; then
            short="$short/$seg"
        else
            short="$short/${seg:0:1}"
        fi
    done
    dir_display="${short#/}"
fi

# ---- vcs segment: branch + staged/unstaged/untracked counts ----
git_seg=""
if [ -n "$git_root" ]; then
    status_output="$(git -C "$cwd" --no-optional-locks status --porcelain --branch 2>/dev/null)"

    branch_line="${status_output%%$'\n'*}"
    branch="${branch_line#\#\# }"
    branch="${branch%%...*}"
    branch="${branch%% \[*}"
    # Detached HEAD reads as "HEAD (no branch)"; show the short sha instead.
    if [ "$branch" = "HEAD (no branch)" ]; then
        branch="$(git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)"
    fi

    read -r staged unstaged untracked <<<"$(printf '%s\n' "$status_output" | awk '
        NR == 1 { next }
        /^\?\?/ { u++; next }
        {
            if (substr($0, 1, 1) != " ") s++
            if (substr($0, 2, 1) != " ") m++
        }
        END { printf "%d %d %d", s + 0, m + 0, u + 0 }
    ')"

    if [ "$staged" -gt 0 ] || [ "$unstaged" -gt 0 ]; then
        branch_fg="$GIT_MODIFIED_FG"
    else
        branch_fg="$GIT_CLEAN_FG"
    fi

    git_seg="${branch_fg}${branch}${RESET}"
    [ "$staged" -gt 0 ] && git_seg="$git_seg ${GIT_MODIFIED_FG}+${staged}${RESET}"
    [ "$unstaged" -gt 0 ] && git_seg="$git_seg ${GIT_MODIFIED_FG}!${unstaged}${RESET}"
    [ "$untracked" -gt 0 ] && git_seg="$git_seg ${GIT_UNTRACKED_FG}?${untracked}${RESET}"
fi

# ---- time segment ----
now="$(date +%H:%M:%S)"

# ---- model/effort segment: prefixed to the line, e.g. "Opus·max" ----
# effort.level is absent for models that don't take an effort parameter;
# that's a normal case, not an error, so just fall back to the bare model name.
model_name="$(printf '%s' "$input" | jq -r '.model.display_name // empty')"
effort_level="$(printf '%s' "$input" | jq -r '.effort.level // empty')"
model_seg=""
if [ -n "$model_name" ]; then
    if [ -n "$effort_level" ]; then
        model_seg="${MODEL_FG}${model_name}·${effort_level}${RESET}  "
    else
        model_seg="${MODEL_FG}${model_name}${RESET}  "
    fi
fi

if [ -n "$git_seg" ]; then
    printf '%s%s%s%s %s  %s%s%s\n' "$model_seg" "$DIR_FG" "$dir_display" "$RESET" "$git_seg" "$TIME_FG" "$now" "$RESET"
else
    printf '%s%s%s%s  %s%s%s\n' "$model_seg" "$DIR_FG" "$dir_display" "$RESET" "$TIME_FG" "$now" "$RESET"
fi
