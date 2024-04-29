#!/bin/sh

# usage
# sudo bash create_user.sh user1 user2

if [ `whoami` != root ]; then
  echo Please run this script as root or using sudo
  exit
fi

create_user() {
  # Create a user with a random password
  useradd -m -s /bin/bash $1
  password=$(openssl rand -base64 14)
  echo "${1}:${password}" | chpasswd
  
  IP=$(hostname -I | awk '{print $1}') # Get the first IP of the machine
  echo "I have created user for you.  ssh ${1}@${IP} , password is \`$password\` (the backquote is not included)"
}

for u in "$@" ; do
    echo "Creating user $u"
    create_user $u
done
