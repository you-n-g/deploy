# Shared shell environment.
# Keep this file POSIX-compatible and lightweight so it can be sourced from
# zsh, bash, and login/profile style startup files.

path_prepend_if_missing() {
    case ":$PATH:" in
        *":$1:"*) ;;
        *) PATH="$1:$PATH" ;;
    esac
}

path_append_if_missing() {
    case ":$PATH:" in
        *":$1:"*) ;;
        *) PATH="$PATH:$1" ;;
    esac
}

path_prepend_if_missing "$HOME/deploy/helper_scripts/bin"
path_prepend_if_missing "$HOME/bin"
path_prepend_if_missing "$HOME/apps/nodejs/bin"
path_prepend_if_missing "$HOME/.luarocks/bin"
path_append_if_missing "$HOME/.local/bin"

export PATH
