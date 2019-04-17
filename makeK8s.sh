#!/bin/bash

# You should source this file to retain the KUBECONFIG env var created in the last script

if [ "$_" == "${BASH_SOURCE}" ]; then
  printf 'ERROR: Source this script; do not execute.\n' >&2
  exit 1
fi

usage () {
  echo "usage: source ./makeK8s.sh [-s centos | ubuntu][-o destDir][-m memSize][-c cpuCnt][-i masterIp][-n network][-t][-d]" >&2
  echo ""
  echo "options:"
  echo " -s specifies either CentOS or Ubuntu nodes"
  echo " -o specifies the destination directory, where kubeconfig files are being collected"
  echo " -m specifies memory for each VM (MB)"
  echo " -c specifies how many vCPUs for each VM"
  echo " -i specifies master IP address"
  echo " -n specifies network, one of calico, canal, flannel, romana, weave"
  echo " -t test only (dry run)"
  echo " -d delete existing cluster only"
  echo "Ctl-c to exit"
  read x
}

masterIp=""
err=0
proj=$(basename $(pwd)) 
dstDir="$HOME/.kube/config.d"
os="ubuntu"
cpu=2
mem=2048
net="calico"
test=0
destroy=0

# must reset OPTIND to parse arguments properly when source'd
OPTIND=1
while getopts o:s:m:c:i:n:td opt; do
  case $opt in
    s) os=$OPTARG     ;;
    o) dstDir=$OPTARG ;;
    m) mem=$OPTARG    ;;
    c) cpu=$OPTARG    ;;
    i) masterIp=$OPTARG ;;
    n) net=$OPTARG    ;;
    t) test=1         ;;
    d) destroy=1      ;;
    \?) echo "Invalid option: -$OPTARG" >&2
      usage 1         ;;
    :) echo "Option -$OPTARG requires an argument." >&2
      usage 1         ;;
  esac
done

dstOpt="-o $dstDir"

if [[ $test -eq 1 ]]; then
  echo "Would destroy existing kubernetes cluster"
else
  echo "Destroy existing kubernetes cluster"
  kcfg=$dstDir/$proj.kubeconfig
  if [[ -f $kcfg ]]; then
    echo "Found kubeconfig file, $kcfg. Deleting it"
    rm $kcfg
  else
    echo "No existing kubeconfig file, $kcfg, found."
  fi
  vagrant destroy -f
fi

if [[ $destroy -eq 1 ]]; then
  echo "Destroy flag set: Destroying cluster, if it exists -- nothing more."
else
  if [[ "$os" == "centos" ]]; then
    echo "makeK8s: Using CentOS"
  elif [[ "$os" == "ubuntu" ]]; then
    echo "makeK8s: Using Ubuntu"
  else
    echo "makeK8s: ERROR: unknown operating system: \"$os\"."
    usage 1
  fi

  if [[ $test -eq 1 ]]; then
    echo "Would create new key-pair for user, vagrant, on all nodes"
  else
    echo "Create new key-pair for user, vagrant, on all nodes"
    yes y | ssh-keygen -t rsa -b 4096 -f id_rsa -N ''
  fi

  if  [[ $os == "centos" ]]; then
    cp Vagrantfile.centos Vagrantfile
  else
    cp Vagrantfile.ubuntu Vagrantfile
  fi

  if [[ $masterIp == "" ]]; then
    # Fetch masterIp from the Vagrantfile
    masterIp=$(grep "\$masterIp " Vagrantfile | awk '{ print $3 }' | cut -f2 -d '"')
    if [[ "$masterIp" == "" ]]; then
      echo "Unable to fetch masterIp from Vagrantfile"
    fi
  fi

  echo "makeK8s: dstOpt:   $dstOpt"
  echo "makeK8s: mem:      $mem"
  echo "makeK8s: cpu:      $cpu"
  echo "makeK8s: masterIp: $masterIp"
  echo "makeK8s: net:      $net"

  # Update cpu/mem in Vagrantfile, as needed
  if [[ ! $cpu == "" ]]; then
    echo "Setting CPU count in Vagrantfile: $cpu"
    sed -i "s/\$cpu         = \"2\"/\$cpu         = \"$cpu\"/" Vagrantfile
    # cpuVal=$(grep '$cpu ' Vagrantfile)
    # echo "cpuVal: $cpuVal"
  fi

  if [[ ! $mem == "" ]]; then
    echo "Setting memory amount in Vagrantfile: $mem"
    sed -i "s/\$mem         = \"2048\"/\$mem         = \"$mem\"/" Vagrantfile
    # memVal=$(grep '$mem ' Vagrantfile)
    # echo "memVal: $memVal"
  fi

  # Update master IP address in Vagrantfile, as needed
  if [[ ! $masterIp == "" ]]; then
    echo "Setting masterIp in Vagrantfile: $masterIp"
    sed -i "/\$masterIp    /c\$masterIp    = \"$masterIp\"" Vagrantfile
    # ipVal=$(grep '$masterIp ' Vagrantfile)
    # echo "ipVal: $ipVal"
  fi

  # Update network in Vagrantfile, as needed
  if [[ ! $net == "" ]]; then
    echo "Setting network in Vagrantfile: $net"
    sed -i "/\$net      /c\$net         = \"$net\"" Vagrantfile
    # netVal=$(grep '$net ' Vagrantfile)
    # echo "netVal: $netVal"
  fi

  # always set the project name, based on pwd
  echo Update Vagrantfile to apply project name: "$proj"
  sed -i "s/\$proj        = \"proj\"/\$proj        = \"$proj\"/" Vagrantfile
  # projVal=$(grep "proj " Vagrantfile)
  # echo "projVal: $projVal"

  if [[ $test -eq 1 ]]; then
    echo " Would call vagrant up"
    echo " Would call pull-k8s-admin.sh"
    echo " Would call modKubeConfigFile.sh"
    echo " Would call setKubeConfigVar.sh"
  else
    if [[ -f $HOME/.ssh/id_rsa.pub ]]; then
      echo "Copying host user's ($LOGNAME) id_rsa.pub key to project directory"
      cp $HOME/.ssh/id_rsa.pub id_rsa.pub.$LOGNAME
    else
      echo "WARNING: File not found: $HOME/.ssh/id_rsa.pub"
    fi

    echo "Calling 'vagrant up' to create new kubernetes cluster"
    vagrant up
    if [[ $? -ne 0 ]]; then
      err=1
    fi

    if [[ $err -eq 0 ]]; then
      echo "Calling pull-k8s-admin.sh to retrieve kube config file (admin.conf), and scrub ~/.ssh/known_hosts"
      cmd="./pull-k8s-admin.sh -i $masterIp"
      echo "cmd: $cmd"
      $cmd
      if [[ $? -ne 0 ]]; then
        err=1
      fi
    fi

    if [[ $err -eq 0 ]]; then
      echo "Calling modKubeConfigFile.sh to re-work kube config file and re-locate to multi-config k8s directory"
      cmd="./modKubeConfigFile.sh -p $proj $dstOpt"
      echo cmd: $cmd
      $cmd
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
  fi
fi
