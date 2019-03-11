#!/bin/bash

cfgdir=$HOME/.kube/config.d

# must reset OPTIND to parse arguments properly when source'd
OPTIND=1
while getopts o: opt; do
  case $opt in
    o)
      cfgdir=$OPTARG
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


if [ "$_" = "${BASH_SOURCE}" ]; then
  printf 'ERROR: Source this script; do not execute.\n' >&2
  exit 1
fi

unset KUBECONFIG

function initConfigVar () {
  if [[ $(ls $cfgdir | grep kubeconfig | wc -l) != 0 ]]; then
    echo "$cfgdir contains one or more kubeconfig files"
    for f in `ls $cfgdir/ | grep kubeconfig`; do
      # echo "Appending $cfgdir/$f to KUBECONFIG"
      export KUBECONFIG="$cfgdir/$f:$KUBECONFIG";
    done
    # Trim trailing '/' character
    export KUBECONFIG=$(echo $KUBECONFIG | sed 's/:$//')
  fi
  kubectl config get-contexts
}

if [[ -d $cfgdir ]]; then
  initConfigVar
else
  echo "ERROR: directory, $cfgdir, does not exist. Exiting."
fi
