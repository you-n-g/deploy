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

unzip_url() {
  url=$1 # URL of the .zip file
  name=$2 # Name of the directory to extract into
  # TODO: download the file and unzip it into a folder $name
  wget --no-check-certificate $url -O $name.zip # download the file
  mkdir -p $name # create a directory with the name
  if [ -e $name ]; then
    rm -rf $name
  fi
  unzip $name.zip -d $name # unzip the file into the directory
  rm $name.zip # remove the downloaded zip file
}

link_to_bin() {
  for app in "$@"; do
    ln -sf ~/apps/$app ~/bin/ # force create or replace the symlink
  done
}
