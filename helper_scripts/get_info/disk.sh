#!/bin/bash

install() {
  if ! command -v fio &> /dev/null; then
    echo "fio is not installed. Installing..."
    sudo apt-get install -y fio
  fi
}

gen_conf() {
  cat << "EOF" > bench.fio
[global]
ioengine=libaio         # 异步IO引擎（Linux推荐）
direct=1                # 绕过缓存，测试真实磁盘性能
runtime=60              # 每项测试持续60秒
time_based              # 基于时间而非传输大小
size=1G                 # 每个job操作数据大小
numjobs=4               # 并发4个任务模拟多线程负载
group_reporting         # 汇总报告

# 顺序写
[seq_write]
rw=write
bs=1M
filename=seq_write_testfile

# 顺序读
[seq_read]
rw=read
bs=1M
filename=seq_write_testfile

# 随机写
[rand_write]
rw=randwrite
bs=4k
filename=rand_write_testfile

# 随机读
[rand_read]
rw=randread
bs=4k
filename=rand_write_testfile  
EOF
}

clean() {
  rm -f bench.fio
  rm seq_write_testfile rand_write_testfile
  # rm -f *_report.txt
}

run() {
  for job in seq_write seq_read rand_write rand_read; do
    fio --section=$job bench.fio --output=${job}_report.txt # --output-format=terse
    echo "Generated report: ${job}_report.txt"
  done
}

summary() {
   for f in $(ls *.txt | sort); do
     echo "===== $f ====="
     grep -A1 "Run status group" "$f"
   done
}

all() {
  install
  gen_conf
  run
  summary
  clean
}

$1 "${@:2}"
