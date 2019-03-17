#!/bin/bash

if [ "$_" = "${BASH_SOURCE}" ]; then
  printf 'ERROR: Source this script; do not execute.\n' >&2
  exit 1
fi

# Default location for kubeconfig files is in $HOME/.kube/config.d
destDir=$HOME/.kube/config.d

# must reset OPTIND to parse arguments properly when source'd
OPTIND=1
while getopts o: opt; do
  case $opt in
    o)
      destDir=$OPTARG
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      ;;
  esac
done

echo "setKubeConfigDir: destDir: $destDir"

unset KUBECONFIG

if [[ -d $destDir ]]; then
  if [[ $(ls $destDir | grep kubeconfig | wc -l) != 0 ]]; then
    echo "$destDir contains one or more kubeconfig files"
    for f in `ls $destDir/ | grep kubeconfig`; do
      # echo "Appending $destDir/$f to KUBECONFIG"
      export KUBECONFIG="$destDir/$f:$KUBECONFIG";
    done
    # Trim trailing '/' character
    export KUBECONFIG=$(echo $KUBECONFIG | sed 's/:$//')
  fi
  kubectl config get-contexts
else
  echo "ERROR: directory, $destDir, does not exist. Exiting."
fi

