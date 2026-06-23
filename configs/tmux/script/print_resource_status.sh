#!/usr/bin/env bash

set -eu

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_ROOT="$(cd -- "${SCRIPT_DIR}/../../.." && pwd)"
SYS_SH="${DEPLOY_ROOT}/helper_scripts/get_info/sys.sh"

is_container_or_limited_cgroup() {
  if [ -f /.dockerenv ] || [ -f /run/.containerenv ]; then
    return 0
  fi

  if [ -r /sys/fs/cgroup/cpu.max ]; then
    read -r quota period < /sys/fs/cgroup/cpu.max
    if [ "${quota}" != max ]; then
      return 0
    fi
  fi

  if [ -r /sys/fs/cgroup/memory.max ]; then
    mem_max="$(cat /sys/fs/cgroup/memory.max)"
    if [ "${mem_max}" != max ]; then
      host_mem="$(awk '/^MemTotal:/{print $2 * 1024}' /proc/meminfo 2>/dev/null || printf 0)"
      if awk -v max="${mem_max}" -v host="${host_mem}" 'BEGIN{exit !(host <= 0 || max < host * 0.98)}'; then
        return 0
      fi
    fi
  fi

  return 1
}

fallback_host_status() {
  plugin_path="${TMUX_PLUGIN_MANAGER_PATH:-${HOME}/.tmux/plugins}/tmux-mem-cpu-load/tmux-mem-cpu-load"
  if [ ! -x "${plugin_path}" ]; then
    printf 'resource status unavailable'
    return 0
  fi
  "${plugin_path}" --colors --powerline-right -g 0 -t 1 --interval 2
}

print_container_status() {
  status="$(sh "${SYS_SH}" get_container_tmux_status 1)"
  set -- ${status}

  cpu_label="$1"
  cpu_used="$2"
  cpu_pct="$3"
  mem_label="$5"
  mem_used="$6"
  mem_pct="$7"

  printf '#[bg=colour28,fg=colour231,bold] %s %s ' "${cpu_used}" "${cpu_pct}"
  printf '#[bg=colour130,fg=colour231,bold] %s %s ' "${mem_used}" "${mem_pct}"
}

if is_container_or_limited_cgroup; then
  if print_container_status; then
    exit 0
  fi
  printf 'cgroup status unavailable'
  exit 0
fi

fallback_host_status
