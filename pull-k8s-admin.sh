#!/bin/bash
# Given the IP address of a master node, and the current USERNAME,
# fetch the cluster's admin.conf file,
# copy the admin.conf file to the user's ~/.kube directory,
# adding the project name to the config filename.
#
# e.g. my project directory is test1 (contains a Vagrantfile for my Kubernetes cluster)
# the master node IP address is 172.1.2.3, and my $USERNAME is dave
#
# This script downloads the admin.config file from the master node using dave's credentials
# (which were previously installed on all nodes during "vagrant up", or by running "post-k8s.sh")
#
# It then copies the file to dave's ~/.kube directory, writing the file as admin.conf.test1.
#
# Why do this?  To provide a config file to use when you want to run kubectl on the host,
# as myself, .against the new cluster.

pgm=$(basename $0)

usage () {
  echo "usage: $pgm -s centos | ubuntu" >&2
  exit $1
}

echo "USERNAME: $USERNAME"

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
  echo "$pgm: ERROR: no operating system specified."
  usage 1
elif [[ "$os" = "centos" ]]; then
  echo "$pgm: Using CentOS"
elif [[ "$os" = "ubuntu" ]]; then
  echo "$pgm: Using Ubuntu"
else
  echo "$pgm: ERROR: unknown operating system specified."
  usage 1
fi

# remove old host keys (Ubuntu)
ssh-keygen -f ~/.ssh/known_hosts -R "master"
ssh-keygen -f ~/.ssh/known_hosts -R "node1"
ssh-keygen -f ~/.ssh/known_hosts -R "node2"

# remove old CentOS host keys
ssh-keygen -f ~/.ssh/known_hosts -R "cmaster"
ssh-keygen -f ~/.ssh/known_hosts -R "cnode1"
ssh-keygen -f ~/.ssh/known_hosts -R "cnode2"

# If ssh gives error about an "Offending key" in known_hosts, use this to correct:
#   sed -i '<n>d' ~/.ssh/known_hosts
# replacing <n> with the number stated by ssh

if [[ "$os" = "centos" ]]; then
  masterIp=192.168.205.15
else
  masterIp=192.168.205.10
fi

# get the current project directory path, then strip away all but the last
dir="$(basename $(pwd))"
echo "dir: $dir"

# pull down the kubernetes admin.conf file from the new master node to the current directory
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $USERNAME@$masterIp:/home/$USERNAME/admin.conf .

