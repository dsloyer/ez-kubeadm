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

# The following steps are perform some useful cleanuip when new cluster instances
# are created.
#
# NOTE: The following ssh-keygen commands work only if lines
# have been added to the hosts file (otherwise, use the IPs of the VM instances):
#   Linux: /etc/hosts
#   Windows: C:\Windows\System32\drivers\etc\hosts
#
echo remove old Ubuntu host keys (if any)
ssh-keygen -f ~/.ssh/known_hosts -R "master"
ssh-keygen -f ~/.ssh/known_hosts -R "node1"
ssh-keygen -f ~/.ssh/known_hosts -R "node2"

echo remove old CentOS host keys (if any)
ssh-keygen -f ~/.ssh/known_hosts -R "cmaster"
ssh-keygen -f ~/.ssh/known_hosts -R "cnode1"
ssh-keygen -f ~/.ssh/known_hosts -R "cnode2"

# NOTE: Later, when ssh'ing to a node, you might get notice of an "Offending key" in the known_hosts file.
# They are complaining that a host with that IP address is already present in the known_hosts file.
# The appearance of a host presenting a different key at a known IP address suggests mishief.
#
# To correct this, make note of the number of the number shown (e.g. 6). Here is the command:
#   $ sed -i '6d' ~/.ssh/known_hosts
#
# To avoid the warning:
#   $ ssh -o StrictHostKeyChecking=no user@host
#
# To permanently disable StrictHostKeyChecking, create or edit ~/.ssh/config, adding this line
#   StrictHostKeyChecking no
#
# Despite disabling StrictHostKeyChecking, ssh will update known_hosts with the new host and key.
# To further avoid adding new entries to known_hosts, add this on the ssh command line, or add 
# to ~/.ssh/config:
#   UserKnownHostsFile=/dev/null

# Here, I've used hard-coded names from the Vagrantfiles
if [[ "$os" = "centos" ]]; then
  master=cmaster
else
  master=master
fi

# get the current project directory path, then strip away all but the last
dir="$(basename $(pwd))"
echo "project directory: $dir"

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

