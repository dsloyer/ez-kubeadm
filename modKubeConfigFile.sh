#!/bin/bash

# Purpose:
#
# The point is to collect kube config files in a known directory, e.g. $HOME/.kube/config.d.
# The contents of this directory can then be assembled in the KUBECONFIG env var, so that
# "kubectl config get-contexts" will offer the array of currently-defined clusters/contexts
# to choose from.
#
# kubeadm produces a config file which will conflict with other kubeadm-generated files.
# In particular, the cluster name, context, and user names overlap.
# Also, the certificate data is embedded in the config file.  I prefer minikube's choice
# to keep the cert files in the project directory ($HOME/.minikube).
#
# In my Vagrant/VirtualBox world, where "vagrant up" invokes kubeadm to spin up a
# kubernetes cluster, I would prefer to extract the certificate data from the config
# file generated by kubeadm, and alter the names so that they reflect the vagrant
# project name (e.g. I have ckube and ukube project directories, for CentOS and Ubuntu-based
# clusters, respectively).
#
# Usage:
# A project name must be specified. It is used to assign cluster, context, user, dest filenames
# An input config file, e.g. $HOME/projects/ckube/admin.conf, generated by kubeadm
# A destination location, e.g. $HOME/.kube/config.d, where the new config file will be found.
#
# To do a test curl after all the changes have been written to the new config file, specify '-t'
#
# NOTE: original config file remains unchanged.

proj=""
fpath=""
destdir="$HOME/.kube/config.d"
cfgdir=""
ipaddr=""
test=0

usage () {
  echo "usage: `basename $0` -p proj[-i cfg-file][-o dest-dir][-a ipaddr][-t]" >&2
  exit $1
}

while getopts a:i:o:p:t opt; do
  case $opt in
    a)
      ipaddr=$OPTARG
      ;;
    i)
      fpath=$OPTARG
      ;;
    o)
      destdir=$OPTARG
      ;;
    p)
      proj=$OPTARG
      ;;
    t)
      test=1
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

if [[ "$proj" = "" ]]; then
  echo ERROR: no project specified.
  usage 1
fi

if [[ "$fpath" = "" ]]; then
  # no input file provided; use assumed location of the project
  fpath="$HOME/projects/$proj/admin.conf"
fi

if [[ "$destdir" = "" ]]; then
  # no destination directory provided; use assumed destination
  destdir="$HOME/.kube/config.d"
fi

if [[ ! -d $destdir ]]; then
  echo "directory, $destdir, does not exist."
  usage 1
fi

echo "project:           $proj"
echo "config file:       $fpath"
echo "dest dir:          $destdir"

# realpath converts relative path to absolute
cfgdir=$(realpath -s $(dirname $fpath))
if [[ ! -d $cfgdir ]]; then
  echo "ERROR: directory, cfgdir, does not exist: \"$cfgdir\""
  exit 1
fi
echo "copy certs to:     $cfgdir"

# paths to the cert files to be generated:
ca_path=$cfgdir/ca.crt
client_path=$cfgdir/client.crt
client_key_path=$cfgdir/client.key
echo "ca_path:           $ca_path"
echo "client_path:       $client_path"
echo "client_key_path:   $client_key_path"

# The cert data in the kubeconfig file appears as a line of text, encoded using
# base64. We store them as individual PEM-formatted files.
# The original cert text can be recovered by running base64 on a PEM file,
# then removing the newline characters.
#
# extract cert data from the config file
export client=$(grep client-cert                $fpath | cut -d " " -f 6)
# echo client: $client
export    key=$(grep client-key-data            $fpath | cut -d " " -f 6)
# echo key: $key
export   auth=$(grep certificate-authority-data $fpath | cut -d " " -f 6)
# echo auth: $auth

# decode the cert data using base64, writing PEM files to the dest location
echo $client | base64 -d - >$client_path
echo $key    | base64 -d - >$client_key_path
echo $auth   | base64 -d - >$ca_path

# set aside a copy of the original config file
cp $fpath $fpath.tmp

# replace the cert data in the config file with paths to the generated PEM files
sed -i "/client-certificate/c\    client-certificate: $client_path"   $fpath
sed -i "/client-key/c\    client-key: $client_key_path"               $fpath
sed -i "/certificate-authority/c\    certificate-authority: $ca_path" $fpath

# replace the cluster and context names with new preferred names (all derived from the project name):
sed -i "/  name: kubernetes$/c\  name: $proj-clu"             $fpath
sed -i "/    cluster: kubernetes/c\    cluster: $proj-clu"    $fpath
sed -i "/  name: kubernetes-admin@kubernetes/c\  name: $proj" $fpath
sed -i "/current-context: kubernetes-admin@kubernetes/c\current-context: $proj" $fpath
sed -i "/    user: kubernetes-admin/c\    user: $proj-admin"  $fpath
sed -i "/- name: kubernetes-admin/c\- name: $proj-admin"      $fpath

if [[ ! "$ipaddr" = "" ]]; then
  # get APIServer port
  # find the server line, strip down to the ip address, remove leading slashes
  #
  #     grep "server:" ../ukube/admin.conf
  #   gives this:
  #     server: https://192.168.205.10:6443
  # 
  # The first "cut" trims all but the 3rd field ("//x.x.x.x")
  # 2nd cut takes the string starting from the 3rd character to the end ("x.x.x.x")
  ipad=$(grep "server: " $fpath | cut -d ":" -f3 | cut -c 3-)
  # echo APIServer ipad: $ipad
  port=$(grep "server: " $fpath | cut -d ":" -f4)
  # echo APIServer port: $port
  sed -i "/    server: /c\    server: https://$ipaddr:$port" $fpath
fi

# copy the final file to the specified destination, and restore original config file
cp $fpath $destdir/$proj.kubeconfig
cp $fpath.tmp $fpath

# test:
if [[ $test -eq 1 ]]; then
  curl --cert $client_path --key $client_key_path --cacert $ca_path https://$ipaddr:$port/api/v1/pods
fi
