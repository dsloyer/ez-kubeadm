#!/bin/bash


# You should source this file to retain the KUBECONFIG env var created in the last script

# echo "I was given $# argument(s):"
# printf "%s\n" "$@"

if [ "$_" = "${BASH_SOURCE}" ]; then
  printf 'ERROR: Source this script; do not execute.\n' >&2
  exit 1
fi

usage () {
  echo "usage: source ./makeK8s.sh [-s centos | ubuntu]" >&2
  read x
}

os="ubuntu"

# must reset OPTIND to parse arguments properly when source'd
OPTIND=1
while getopts s: opt; do
  case $opt in
    s)
      os=$OPTARG
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      usage 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      usage 1
      ;;
  esac
done

if [[ "$os" = "" ]]; then
  echo "ERROR: no operating system specified."
  usage 1
elif [[ "$os" = "centos" ]]; then
  echo "Using CentOS"
elif [[ "$os" = "ubuntu" ]]; then
  echo "Using Ubuntu"
else
  echo "ERROR: unknown operating system: \"$os\"."
  usage 1
fi

echo "Destroy existing kubernetes cluster"
vagrant destroy -f

echo "Create new key-pair for user, vagrant, on all nodes"
yes y | ssh-keygen -t rsa -b 4096 -f id_rsa -N ''

if  [[ $os == "centos" ]]; then
  cp Vagrantfile.centos Vagrantfile
else
  cp Vagrantfile.ubuntu Vagrantfile
fi

echo "Create new kubernetes cluster"
vagrant up

echo "Retrieve kube config file (admin.conf), and scrub ~/.ssh/known_hosts"
./pull-k8s-admin.sh -s $os

echo "re-work kube config file and re-locate to multi-config k8s directory"
./modKubeConfigFile.sh -p $(basename $(pwd))

echo "set KUBECONFIG env var."
source ./setKubeConfigVar.sh

