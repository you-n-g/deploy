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
  echo -e "\033[1;33mMemory Information:\033[0m"
  free -h
  echo

  # Show disk information
  echo -e "\033[1;33mDisk Information:\033[0m"
  lsblk -d -o name,rota 
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
