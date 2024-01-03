#!/bin/sh

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
