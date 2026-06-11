#!/bin/sh

get_hw_info() {
  # Show OS information
  echo
  echo -e "\033[1;33mOS Information:\033[0m"
  lsb_release -a
  echo

  # Show CPU information
  echo -e "\033[1;33mCPU Information:\033[0m"
  lscpu  | grep -E "Model name:|^CPU\(s\):|Socket\(s\)"
  echo

  # Show GPU information
  echo -e "\033[1;33mGPU Information:\033[0m"
  nvidia-smi -L
  echo

  # Show memory information
  echo -e "\03refactor3[1;33mMemory Information:\033[0m"
  free -h
  echo

  # Show disk information
  echo -e "\033[1;33mDisk Information:\033[0m"
  lsblk -d -o name,rota 
  echo
  df -h
  echo
}


get_glibc_info() {
  ldd --version
}


get_performance_info() {
    sudo apt-get -y install fio
    # reading performance
    fio --name=randread --ioengine=libaio --iodepth=16 --rw=randread --bs=4k --direct=0 --size=512M --numjobs=2 --runtime=240 --group_reporting
    # writing performance
    fio --name=randwrite --ioengine=libaio --iodepth=16 --rw=randwrite --bs=4k --direct=0 --size=512M --numjobs=2 --runtime=240 --group_reporting
 }


get_dir_performance_info() {
  target_dir="${1:-/workspace}"
  bs="${2:-4k}"
  size="${3:-2G}"
  jobs="${4:-2}"
  iodepth="${5:-16}"

  # Normalize path and test file name
  file="${target_dir%/}/fio_test_file"

  echo "Preconditioning: creating ${size} test file at ${file} (direct I/O)"
  fio --name=fill --filename="${file}" --ioengine=libaio --rw=write --bs=1M --size="${size}" --direct=1 --numjobs=1 --group_reporting

  echo "Random read test on ${file}"
  fio --name=randread --filename="${file}" --ioengine=libaio --iodepth="${iodepth}" --rw=randread --bs="${bs}" --direct=1 --numjobs="${jobs}" --time_based --runtime=30 --group_reporting

  echo "Random write test on ${file} (will unlink afterwards)"
  fio --name=randwrite --filename="${file}" --ioengine=libaio --iodepth="${iodepth}" --rw=randwrite --bs="${bs}" --direct=1 --numjobs="${jobs}" --time_based --runtime=30 --group_reporting --unlink=1
}


get_port_info() {
  printf "\n\033[1;33mPort Usage Summary:\033[0m\n"

  if command -v ss >/dev/null 2>&1; then
    tcp_ports=$(ss -tln | awk '/LISTEN/{c++} END{print c+0}')
    udp_ports=$(ss -uln | awk 'NR>1{c++} END{print c+0}')
    echo "Listening ports (TCP): $tcp_ports"
    echo "UDP sockets: $udp_ports"
    usage_pct=$(awk -v c="$tcp_ports" 'BEGIN{printf "%.2f", c * 100 / 65536}')
    echo "Port range usage (TCP, 0-65535): ${usage_pct}%"

  elif command -v netstat >/dev/null 2>&1; then
    tcp_ports=$(netstat -tln | awk '/LISTEN/{c++} END{print c+0}')
    udp_ports=$(netstat -uln | awk 'NR>2{c++} END{print c+0}')
    echo "Listening ports (TCP): $tcp_ports"
    echo "UDP sockets: $udp_ports"
    usage_pct=$(awk -v c="$tcp_ports" 'BEGIN{printf "%.2f", c * 100 / 65536}')
    echo "Port range usage (TCP, 0-65535): ${usage_pct}%"

  else
    echo "No port listing tool found (ss/netstat)."
    return 1
  fi
}


# get_container_cpu_info: container-aware CPU usage + capacity from cgroup v2.
#
# `nproc` / `lscpu` show the host topology, which is misleading inside a
# cgroup-limited container — they return the bare metal count, not the slice
# the container is actually allowed to burn. This reads /sys/fs/cgroup/cpu.max
# (the cfs quota), samples cpu.stat over $1 seconds (default 1) for live
# usage, and reports cpu.pressure (PSI) so you can tell whether the cgroup
# is throttling you.
#
# Output one line:
#   cpu: <used>/<quota> CPU (<pct>)  PSI some/full(10s): <s>% / <f>%  throttled: <n>
#
# Reading guide:
#   - <used> close to <quota> AND PSI some > 0   → quota saturated, more
#                                                  parallelism won't help
#   - PSI full > 0                                → all in-cgroup tasks are
#                                                  stalled on CPU at once
#   - throttled climbing across calls             → cgroup actively pressing
#                                                  the brake (~ PSI full > 0)
#
# Optional arg: $1 = sample window in seconds (default 1).
get_container_cpu_info() {
  local secs="${1:-1}"
  if [ ! -r /sys/fs/cgroup/cpu.max ]; then
    echo "cgroup v2 cpu.max not readable (legacy cgroup v1 or non-Linux?)" >&2
    return 1
  fi
  local q p qcpu u0 u1 cpu_eq pct s10 f10 nthr
  read q p < /sys/fs/cgroup/cpu.max
  if [ "$q" = max ]; then
    qcpu="∞"
  else
    qcpu=$(awk -v q="$q" -v p="$p" 'BEGIN{printf "%g", q/p}')
  fi
  u0=$(awk '/^usage_usec/{print $2}' /sys/fs/cgroup/cpu.stat)
  sleep "$secs"
  u1=$(awk '/^usage_usec/{print $2}' /sys/fs/cgroup/cpu.stat)
  cpu_eq=$(awk -v a="$u0" -v b="$u1" -v t="$secs" \
            'BEGIN{printf "%.2f", (b-a)/1e6/t}')
  if [ "$qcpu" = "∞" ]; then
    pct="-"
  else
    pct=$(awk -v c="$cpu_eq" -v q="$qcpu" \
            'BEGIN{printf "%.0f%%", c/q*100}')
  fi
  s10=$(grep ^some /sys/fs/cgroup/cpu.pressure | grep -oE 'avg10=[0-9.]+' | cut -d= -f2)
  f10=$(grep ^full /sys/fs/cgroup/cpu.pressure | grep -oE 'avg10=[0-9.]+' | cut -d= -f2)
  nthr=$(awk '/^nr_throttled/{print $2}' /sys/fs/cgroup/cpu.stat)
  printf 'cpu: %s/%s CPU (%s)  PSI some/full(10s): %s%% / %s%%  throttled: %s\n' \
    "$cpu_eq" "$qcpu" "$pct" "$s10" "$f10" "$nthr"
}

usage() {
  cat >&2 <<'EOF'
Usage:
  sys.sh <function> [args...]

Functions:
  get_hw_info
  get_glibc_info
  get_performance_info
  get_dir_performance_info [target_dir] [bs] [size] [jobs] [iodepth]
  get_port_info
  get_container_cpu_info [sample_seconds]

Remote examples:
  curl -fsSL https://raw.githubusercontent.com/you-n-g/deploy/master/helper_scripts/get_info/sys.sh | bash -s -- get_container_cpu_info
  curl -fsSL https://raw.githubusercontent.com/you-n-g/deploy/master/helper_scripts/get_info/sys.sh | bash -s -- get_container_cpu_info 2
EOF
}

main() {
  cmd="${1:-}"
  [ -n "$cmd" ] || { usage; exit 2; }
  shift

  case "$cmd" in
    get_hw_info|get_glibc_info|get_performance_info|get_dir_performance_info|get_port_info|get_container_cpu_info)
      "$cmd" "$@"
      ;;
    -h|--help|help)
      usage
      ;;
    *)
      echo "Unknown function: $cmd" >&2
      usage
      exit 2
      ;;
  esac
}

main "$@"
