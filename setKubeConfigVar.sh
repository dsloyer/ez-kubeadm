#!/bin/bash

cfgdir=$HOME/.kube/configd

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
    echo "Put kubeconfigs in $cfgdiir/ and source this profile to load."
fi;
