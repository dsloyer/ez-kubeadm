#!/bin/bash

# You should source this file to retain the KUBECONFIG env var created in the last script

err=0

if [ "$_" = "${BASH_SOURCE}" ]; then
  printf 'ERROR: Source this script; do not execute.\n' >&2
  exit 1
fi

usage () {
  echo "usage: source ./makeK8s.sh [-s centos | ubuntu][-o destDir]" >&2
  echo "\n"
  echo "options:"
  echo " -s specifies either CentOS or Ubuntu nodes"
  echo " destDir indicates the directory where kubeconfig files are being collected"
  echo "Ctl-c to exit"
  read x
}

dstOpt=""
os="ubuntu"

# must reset OPTIND to parse arguments properly when source'd
OPTIND=1
while getopts o:s: opt; do
  case $opt in
    o)
      dstOpt="-o $OPTARG"
      ;;
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

echo "Calling 'vagrant up' to create new kubernetes cluster"
vagrant up
if [[ $? -ne 0 ]]; then
  err = 1
fi

if [[ $err -eq 0 ]]; then
  echo "Calling pull-k8s-admin.sh to retrieve kube config file (admin.conf), and scrub ~/.ssh/known_hosts"
  ./pull-k8s-admin.sh -s $os
  if [[ $? -ne 0 ]]; then
    err=1
  fi
fi

if [[ $err -eq 0 ]]; then
  echo "Calling modKubeConfigFile.sh to re-work kube config file and re-locate to multi-config k8s directory"
  ./modKubeConfigFile.sh -p $(basename $(pwd)) $dstOpt
  if [[ $? -ne 0 ]]; then
    err=1
  fi
fi

if [[ $err -eq 0 ]]; then
  echo "Calling setKubeConfigVar.sh to set KUBECONFIG env var."
  source ./setKubeConfigVar.sh $dstOpt
  if [[ $? -ne 0 ]]; then
    err=1
  fi
fi

