#!/bin/bash
# Given the IP address of a master node, and the current LOGNAME,
# fetch the cluster's admin.conf file,
# copy the admin.conf file to the user's ~/.kube directory,
# adding the project name to the config filename.
#
# e.g. my project directory is test1 (contains a Vagrantfile for my Kubernetes cluster)
# the master node IP address is 172.1.2.3, and my $LOGNAME is dave
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

echo "LOGNAME: $LOGNAME"

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

# NOTE: The following ssh-keygen commands work only if lines
# have been added to the hosts file:
#   Linux: /etc/hosts
#   Windows: C:\Windows\System32\drivers\etc\hosts
#
# remove old host keys (Ubuntu)
ssh-keygen -f ~/.ssh/known_hosts -R "master"
ssh-keygen -f ~/.ssh/known_hosts -R "node1"
ssh-keygen -f ~/.ssh/known_hosts -R "node2"

# remove old CentOS host keys
ssh-keygen -f ~/.ssh/known_hosts -R "cmaster"
ssh-keygen -f ~/.ssh/known_hosts -R "cnode1"
ssh-keygen -f ~/.ssh/known_hosts -R "cnode2"

# Here, I've used hard-coded names from the Vagrantfiles
if [[ "$os" = "centos" ]]; then
  master=cmaster
else
  master=master
fi

# get the current project directory path, then strip away all but the last
dir="$(basename $(pwd))"
echo "dir: $dir"

# pull down the kubernetes admin.conf file from the new master node to the current directory
while true; do
  scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $LOGNAME@$master:/home/$LOGNAME/admin.conf .
  if [[ $? -eq 0 ]]; then
    echo "scp attempt to pull admin.conf file gave no error"
    break
  else
    echo "scp attempt to pull admin.conf file failed"
    sleep 10
  fi
done

