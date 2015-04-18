#!/bin/bash

curl -sSL https://get.docker.com/ubuntu/ | sudo -E sh
# -E for http_proxy


# on 12.04
# if it report 
# FATA[0000] Shutting down daemon due to errors: Error loading docker apparmor profile: exit status 1 (Feature buffer full.)
# sudo apt-get install apparmor
