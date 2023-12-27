#!/bin/sh


function stress_cpu() {
  # get cpu cores
  cores=$(grep -c '^processor' /proc/cpuinfo)
  echo $cores
  # install stress
  sudo apt-get install -y stress
  stress --cpu $cores --timeout 10h
}



function sensor_cpu() {
  sudo apt-get install -y lm-sensors
  logfile="sensor_$(date +"%Y%m%d_%H%M%S").log"

  while true ; do
    date +"datetime: %Y%m%d_%H%M%S" >> $logfile
    sensors >>  $logfile
    sleep 2
  done
}


# `./stress.sh sensor_cpu` to record temperature
# `./stress.sh stress_cpu` to run stress to occupy CPU

$1
