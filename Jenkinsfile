env.k8sproj = "ckube"
env.k8sos   = "centos"
env.k8snet  = "flannel"
env.k8smem  = "4096"
node('linux') {
   stage('Preparation') {
      // Ensure env is right
      sh '''#!/bin/bash
        cd $HOME
        if [[ ! -d projects ]]; then echo "mkdir projects"&&mkdir projects; fi
        cd $HOME/projects
        if [[   -d ez-kubeadm ]]; then rm -rf ez-kubeadm; fi
        echo "Clone ez-kubeadm from github"
        git clone https://github.com/dsloyer/ez-kubeadm.git'''
   }
   stage('BuildCluster') {
      sh '''#!/bin/bash
        cd $HOME/projects
        if [[ ! -d ${k8sproj} ]]; then echo "Making ${k8sproj} directory"&&mkdir ${k8sproj}; fi
        cd $HOME/projects/${k8sproj}
        if [[ ! -d .vagrant ]]; then echo "vagrant init"&&vagrant init; fi
        cp ../ez-kubeadm/* .
        echo "Running makeK8s.sh"
        source ./makeK8s.sh -s ${k8sos} -n ${k8snet} -m ${k8smem}'''
   }
   stage('Run a Pod') {
      sh '''#!/bin/bash
        cd $HOME/projects/${k8sproj}
        source ./setKubeConfigVar.sh
        kubectl config use-context ${k8sproj}
        echo "Running a pod"
        kubectl run nginx --image nginx
        sleep 10
        kubectl get pods'''
   }
}
