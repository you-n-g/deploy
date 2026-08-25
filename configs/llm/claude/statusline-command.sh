#!/usr/bin/env bash
# Claude Code statusline modeled on the user's powerlevel10k prompt
# (~/deploy/configs/shell/p10k.zsh). The segments actually enabled there are:
#   left:  dir, vcs (git status), prompt_char
#   right: time, plus many env-manager segments (aws, gcloud, kubecontext,
#          pyenv, nodenv, ...) that p10k only shows while typing a matching
#          command, i.e. not a steady-state part of the prompt.
#
# For a single-line Claude Code status we mirror only the steady-state,
# always-relevant segments: dir, git branch/status, and conda/venv env.
# `prompt_char`, `status` (exit code) and `time` don't map to anything
# meaningful in Claude Code (no command is being typed/executed), so they're
# left out; the command-triggered segments (aws/gcloud/kubecontext/...) are
# skipped for the same reason.
#
# Prepended/appended: model name (+ effort level) and context-window usage.
# Neither has a p10k equivalent, but both are useful in a Claude Code status
# line and were requested separately from the p10k migration.
#
# Renders: <model>  <dir> <git-branch [+staged !unstaged ?untracked]>  <conda/venv env>  ctx:NN%
# using the same color numbers as the p10k config where a segment has one.
#
# Git calls pass --no-optional-locks so they never block on a repo lock held
# by another process (e.g. another agent running in the same worktree), and
# the whole vcs segment comes from a single `status --porcelain --branch`
# rather than one subprocess per counter.

set -u

RESET=$'\e[0m'
DIR_FG=$'\e[38;5;31m'                 # POWERLEVEL9K_DIR_FOREGROUND
GIT_BRANCH_FG=$'\e[38;5;76m'          # my_git_formatter()'s $clean, applied to the branch name itself
GIT_MODIFIED_FG=$'\e[38;5;178m'       # my_git_formatter()'s $modified, for +staged / !unstaged
GIT_UNTRACKED_FG=$'\e[38;5;39m'       # my_git_formatter()'s $untracked, for ?untracked
ENV_FG=$'\e[38;5;37m'                 # POWERLEVEL9K_VIRTUALENV_FOREGROUND / POWERLEVEL9K_ANACONDA_FOREGROUND
MODEL_FG=$'\e[38;5;141m'              # not a p10k segment; added for model/effort display
CTX_FG=$'\e[38;5;244m'                # not a p10k segment; dimmed grey (p10k's "stale vcs" grey) for context usage

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

# ---- vcs segment: branch (always green, per my_git_formatter's $clean) + counts ----
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

    git_seg="${GIT_BRANCH_FG}${branch}${RESET}"
    [ "$staged" -gt 0 ] && git_seg="$git_seg ${GIT_MODIFIED_FG}+${staged}${RESET}"
    [ "$unstaged" -gt 0 ] && git_seg="$git_seg ${GIT_MODIFIED_FG}!${unstaged}${RESET}"
    [ "$untracked" -gt 0 ] && git_seg="$git_seg ${GIT_UNTRACKED_FG}?${untracked}${RESET}"
fi

# ---- env segment: conda/venv, whichever is active. This reads directly from
# the environment (not the stdin JSON) since Claude Code inherits it from the
# shell that launched it, same as p10k's virtualenv/anaconda segments do.
# "base" is hidden, matching how most people treat the default conda env.
env_seg=""
if [ -n "${VIRTUAL_ENV:-}" ]; then
    env_seg="${ENV_FG}$(basename "$VIRTUAL_ENV")${RESET}"
elif [ -n "${CONDA_DEFAULT_ENV:-}" ] && [ "$CONDA_DEFAULT_ENV" != "base" ]; then
    env_seg="${ENV_FG}${CONDA_DEFAULT_ENV}${RESET}"
fi

# ---- model/effort segment: prefixed to the line, e.g. "Opus·max" ----
# effort.level is absent for models that don't take an effort parameter;
# that's a normal case, not an error, so just fall back to the bare model name.
model_name="$(printf '%s' "$input" | jq -r '.model.display_name // empty')"
effort_level="$(printf '%s' "$input" | jq -r '.effort.level // empty')"
model_seg=""
if [ -n "$model_name" ]; then
    if [ -n "$effort_level" ]; then
        model_seg="${MODEL_FG}${model_name}·${effort_level}${RESET}"
    else
        model_seg="${MODEL_FG}${model_name}${RESET}"
    fi
fi

# ---- context usage segment ----
ctx_pct="$(printf '%s' "$input" | jq -r '.context_window.used_percentage // empty')"
ctx_seg=""
if [ -n "$ctx_pct" ]; then
    ctx_seg="${CTX_FG}ctx:$(printf '%.0f' "$ctx_pct")%${RESET}"
fi

# ---- assemble: model  dir git-status  env  ctx ----
segs=()
[ -n "$model_seg" ] && segs+=("$model_seg")
if [ -n "$git_seg" ]; then
    segs+=("${DIR_FG}${dir_display}${RESET} ${git_seg}")
else
    segs+=("${DIR_FG}${dir_display}${RESET}")
fi
[ -n "$env_seg" ] && segs+=("$env_seg")
[ -n "$ctx_seg" ] && segs+=("$ctx_seg")

out=""
for seg in "${segs[@]}"; do
    if [ -z "$out" ]; then
        out="$seg"
    else
        out="$out  $seg"
    fi
done
printf '%s\n' "$out"
