#!/bin/sh

untar_url() {
  # NOTE: it only support `.tar.gz`
  url=$1 # NOTE: it will be XXX.tar.gz
  name=$2
  # TODO: download the file and untar it into a folder $name
  wget --no-check-certificate $url -O $name.tar.gz # download the file
  mkdir $name # create a directory with the name
  tar -xzf $name.tar.gz -C $name # untar the file into the directory
  rm $name.tar.gz # remove the downloaded tar.gz file
}

link_to_bin() {
  for app in "$@"; do
    ln -s ~/apps/$app ~/bin/
  done
}
