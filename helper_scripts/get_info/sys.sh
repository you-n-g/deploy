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

$1
