#!/bin/bash

if [ "$_" = "${BASH_SOURCE}" ]; then
  printf 'ERROR: Source this script; do not execute.\n' >&2
  exit 1
fi

cfgdir=$HOME/.kube/config.d

unset KUBECONFIG
if [[ -f $cfgdir ]]; then
    echo "file, $cfgdir, exists."
    if [[ $(grep minikube $cfgdir | wc -l ) != 0 ]]; then
        echo "No errant kubeconfigs."
    fi
fi

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
    mkdir $cfgdir
    echo "Created directory, $cfgdir"
    echo "Put kubeconfigs in $cfgdir/ and source this script to load."
fi;
