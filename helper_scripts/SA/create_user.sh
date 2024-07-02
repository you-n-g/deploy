#!/bin/sh

# usage
# sudo bash create_user.sh user1 user2

if [ `whoami` != root ]; then
  echo Please run this script as root or using sudo
  exit
fi

# https://stackoverflow.com/a/34531699
ADD_DOCKER_PERM=false
SKIP_CREATE_USER=false
USER_LIST=""
while getopts ":dku:" opt; do
    case $opt in
        d)
        echo "Adding docker perm" >&2
        ADD_DOCKER_PERM=true
        ;;
        k)
        echo "skipping creating user" >&2
        SKIP_CREATE_USER=true
        ;;
        u)
        echo "user list: $OPTARG" >&2
        USER_LIST=$OPTARG
        ;;
        \?)
        echo "Invalid option: -$OPTARG" >&2
        exit 1
        ;;
        :)
        echo "Option -$OPTARG requires an argument." >&2
        exit 1
        ;;
    esac
done

create_user() {
  # Create a user with a random password
  useradd -m -s /bin/bash $1
  password=$(openssl rand -base64 14)
  echo "${1}:${password}" | chpasswd
  
  IP=$(hostname -I | awk '{print $1}') # Get the first IP of the machine
  echo "I have created user for you.  ssh ${1}@${IP} , password is \`$password\` (the backquote is not included)"
}

add_docker_perm() {
  # Check if Docker is installed
  if command -v docker >/dev/null 2>&1; then
    echo "Docker is installed, adding user $1 to the docker group"
    sudo usermod -aG docker $1
  else
    echo "Docker is not installed, skipping docker permission for user $1"
  fi
}

for u in "$USER_LIST" ; do
    if [ $SKIP_CREATE_USER = false ]; then
      echo "Creating user $u"
      create_user $u
    fi
    if [ $ADD_DOCKER_PERM = true ]; then
      echo "Adding docker perm for $u"
      add_docker_perm $u
    fi
done
