## Create Local Multi-node Kubernetes Clusters In One Simple Command

This project has a simple aim: make is easy to create multi-node Kubernetes clusters, in a local
environment, with a single command.  Also, to support several clusters, and easy switching between
them.

Why use ez-kubeadm?  Because the steps are clear and simple, removing, as far as
possible, all guesswork and risk.  My interest, beyond taking it as a modest "Infrastructure as
Code" personal challenge, was to:
* Avoid a sometimes fragmented, often confusing, process of deployment via other solutions.
* Applying a "canonical" Kubernetes deployment solution, kubeadm, whose steps can be easily seen
  to be consistent with the steps appearing in kubernetes.io for kubeadm (actually copied/pasted
  from there, whenever possible).
* Combine and consolidate the steps scattered across kubernetes.io's kubeadm setup webpage
  (kubeadm, CRI, CNI, etc), to a single command.
* Implement it such that discarding, and recreating, a working cluster is trivial, reliable, and
  fast.
* Document the tools, applications needed (what to install, and where to find).
* Gather issues observed in testing, and catalogue their resolution.
* Support both Linux and Windows 10 WSL (Windows Subsystem for Linux) hosts.
* Package it as a small bundle of files.

All the files that comprise this project are in https://github.com/dsloyer/ez-kubeadm

Inspiration provided by: Raj Rajaratnam. Thank you, Raj!

## Overview
* **Kubeadm** is the tool used to deploy the cluster.
* **Vagrant** installs and configures the Ubuntu/CentOS boxes on **VirtualBox**.
* **Bash scripts** manage the process, perform further operations on the cluster nodes, providing a
  seamless experience.
* To better support multiple kubernetes configurations, ez-kubeadm gathers its generated kubeconfig
  files in a directory, **$HOME/.kube/config.d**, and sets the KUBECONFIG env var based on
  the contents of that directory.

The Kubernetes master and worker node VMs can be either Ubuntu(default) or CentOS. CentOS is easily
selected via runtime parameter, as are network (CNI), memory, and CPU settings.

Currently supporting any of five networking alternatives, a CNI network is selected via parameter
-- one of {calico, canal, flannel, romana, weave}.  Calico is deployed by default.  You may
not care what network is being used -- I included them as an exercise for me.  If you're interested
in exploring, for example, network policies, you may find one network, or another, to be of interest.

A complete Kubernetes cluster can be built with a single command in the project directory.
Before running that command, you first must do some modest preparation:
  1. clone this repository locally (into, say, $HOME/projects/ez-kubeadm)
  2. install vagrant and VirtualBox
  3. setup directories and env variables. All this is described in detail, below.

As of mid-April, 2019, this script creates a 3-node k8s cluster (master and 2 worker nodes), with
these versions:
  * Kubernetes: 1.14.1                          (current version on kubernetes.io)
  * Docker:     18.06.2                         (prescribed by kubernetes.io)
  * Centos:     CentOS7,                        (prescribed by kubernetes.io))
    * Version:  1902.01                         (latest CentOS7 box from Vagrant)
  or
  * Ubuntu:     Ubuntu/xenial64                 (prescribed by kubernetes.io)
    * Version   20190411.0.0                    (latest Ubuntu Xenial box from Vagrant)
    
## Show Me
Assuming you've setup your system per the instructions below, a few simple steps prepare for an
entirely new cluster. Let's call it 'ukube':
```
$ cd $HOME/projects
$ mkdir ez-kubeadm && cd ez-kubeadm
$ git init && git pull https://github.com/dsloyer/ez-kubeadm.git
$ cd $HOME/projects
$ mkdir ukube && cd ukube
$ vagrant init
$ cp ../ez-kubeadm/* .
$ source ./makeK8s.sh -h
usage: source ./makeK8s.sh [-h][-s centos | ubuntu][-o destDir][-m memSize][-c cpuCnt][-i masterIp][-n network][-t][-d]
options:
  -s specifies either CentOS or Ubuntu nodes
  -o specifies the destination directory, where kubeconfig files are being collected
  -m specifies memory for each VM (MB)
  -c specifies how many vCPUs for each VM
  -i specifies master IP address
  -n specifies network, one of calico, canal, flannel, romana, weave
  -t test only (dry run)
  -d delete existing cluster only
Ctl-c to exit
```
You're ready to create a cluster, or destroy and recreate an Ubuntu-based Kubernetes cluster,
anytime, from this directory, with a single command:
```
$ source ./makeK8s.sh
```
About 10 minutes later, the cluster is up and ready to use:
```
$ kubectl config use-context ukube
Switched to context "ukube".
$ kubectl get nodes
NAME           STATUS   ROLES    AGE     VERSION
ukube-master   Ready    master   5m41s   v1.14.1
ukube-node1    Ready    <none>   3m8s    v1.14.1
ukube-node2    Ready    <none>   21s     v1.14.1                                                                             
```
Let's change directory, spin up an nginx container pod, ssh to the master node, and list the running pods:
```
$ cd ~/projects/test
$ kubectl run nginx --restart=Never --image=nginx
pod/nginx created

$ ssh ukube-master
The authenticity of host 'ukube-master (192.168.205.10)' can't be established.
ECDSA key fingerprint is SHA256:ZTr59SXk32ud7sIfynwjfNC6mlq92cG8iFm0Hbp69j4.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added 'ukube-master,192.168.205.10' (ECDSA) to the list of known hosts.
Welcome to Ubuntu 16.04.6 LTS (GNU/Linux 4.4.0-143-generic x86_64)
--- some text removed ---

username@ukube-master:~$ kubectl get po
NAME   READY   STATUS    RESTARTS   AGE
nginx  1/1     Running   0          2m46s
```
Destroy the cluster by cd'ing into the project folder for the cluster, then run:
```
$ source ./makeK8s.sh -d
```
or
```
$ vagrant destroy -f
```
Using "makeK8s.sh -d" removes stale kubeconfig files, and might be preferred for that reason.

To create a cluster configured with these parameter settings:
 * CentOS OS as node operating system,
 * Flannel networking,
 * node IPs starting from master, at 192.168.44.50,
 * 3 cpus per node, and
 * 4096MB memory each
apply the following parameter values in the call to makeK8s:
```
$ source ./makeK8s.sh -s centos -n flannel -i 192.168.44.50 -c 3 -m 4096
```
## Setup Instructions:
The setup for native Ubuntu Linux and Windows WSL (Ubuntu) is virtually identical, other than
a few additional commands I've detailed just below.

  1. Install kubectl on your host system, per instructions on kubernetes.io.
     One method (https://kubernetes.io/docs/tasks/tools/install-kubectl/):
       ```
       $ curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
       $ chmod +x kubectl
       $ sudo mv kubectl /usr/local/bin
       ```
     Make it executable and move to a preferred directory in your path, e.g. /usr/local/bin, as
     seen above
  2. Install VirtualBox 5.2.26 for your system (VirtualBox 6.0 seems to present several painful issues).
     On Linux, install VirtualBox for Linux. For Windows WSL, install the Windows version, not the
     Linux version.
     NOTE: We assume you've enabled virtualization in the BIOS, and that no conflicting
     virtualization schemes have been enabled (e.g. Windows Hyper-V)
  3. [WSL only] Add VirtualBox binaries to System PATH, found at
       System->Properties->Adv System Settings->Environment Variables...->System variables
     The VirtualBox path is typically c:\Program Files\Oracle\VirtualBox, which you append to the
     System PATH.
     
     As discussed below, it's a good idea to locate the projects directory in, e.g.,
     C:\Users\$LOGNAME\projects,
     Set a symlink from /home/$LOGNAME/projects to that projects directory, set env vars also listed
     here, and specify metadata on the mounted C: drive:
     ```
     $ ln -s /mnt/c/Users/$LOGNAME/projects $HOME/projects
     $ echo "export VAGRANT_WSL_WINDOWS_ACCESS_USER_HOME_PATH=/home/$LOGNAME/projects" >>$HOME/.bashrc && source $HOME/.bashrc
     $ echo "export VAGRANT_WSL_ENABLE_WINDOWS_ACCESS=1" >>$HOME/.bashrc && source $HOME/.bashrc
     $ echo "export VAGRANT_HOME=\"$HOME/.vagrant.d\""      >>$HOME/.bashrc && source $HOME/.bashrc
     $ sudo umount /mnt/c && sudo mount -t drvfs C: /mnt/c -o metadata
     ```
  4. Install vagrant for Linux in bash (both Linux and Windows WSL). I used
     ```
     $ wget https://releases.hashicorp.com/vagrant/2.2.4/vagrant_2.2.4_x86_64.deb
     $ sudo apt-get install ./vagrant_2.2.4_x86_64.deb
     ```
  5. Clone ez-kubeadm into your projects directory, e.g. #HOME/projects/ez-kubeadm.
  6. Create a project directory specific to the new kubernetes cluster; e.g. $HOME/projects/ukube/.
  8. cd to the specific kubernetes cluster project directory, e.g. $HOME/projects/ukube
  9. Run "vagrant init"
     ```
     $ vagrant init
     ```
  10. Copy the collection of files from this repo into the project directory
      ```
      $ cp ../ez-kubeadm/* .
      ```
  11. ez-kubeadm expects you to have an id_rsa.pub file $HOME/.ssh, which it will copy into the
      project directory for the new cluster. If needed, use "ssh-keygen -t rsa -b 4096 -f id_rsa"
      to produce one.
  12. Consider the CPU/memory settings in the relevant Vagrantfile -- either Vagrantfile.ubuntu, or
      Vagrantfile.centos.  By default, all nodes receive 2048MB of RAM, and 2 vCPUs.
      If you want to change them, add a parameter for the desired change in the next step. E.g, if
      you want 3 vCPUs and 4GB of memory, add "-c 3 -m 4096" to the command below.
  13. The IP address of the master node can be changed by using the "-i" option with the command to
      makeK8s.sh; e.g. "-i 192.147.233.30".  Avoid using a master IP that ends with a digit higher
      than 7, or the IP addresses may not be monotonically increasing (e.g. master: 192.168.50.68,
      node1: 192.168.50.69, node2: 192.168.50.60).
  14. Run "source ./makeK8s.sh", or "source ./makeK8s.sh -s centos" to create a new cluster
## Notes 
  1. Edits to the Vagrantfile (Vagrantfile.ubuntu or Vagrantfile.centos) should only be needed to:
     * make permanent changes to default memory or CPU settings for the nodes
     * make permanent changes to the default IP addresses.
       Ubuntu master IP is 192.168.205.10; worker node IPs immediately follow, i.e. node1 is
       192.168.205.11
       CentOS cmaster IP is 192.168.205.15; worker node IPs immediately follow, i.e. cnode1 is
       192.168.205.16
     * want more/fewer nodes? edit the servers array
  2. To set the KUBECONFIG env var at any time, e.g. on a new shell instance, cd to the project
     directory, and "source" the script, setKubeConfigVar.sh:
     ```
     $ source ./setKubeConfigVar.sh
     ```
     Consider copying this script into your path, somewhere.
  3. Only one context can be active at a time, across multiple shells.
  4. Several clusters can exist at any point in time.  View available configs using:
     ```
     $ kubectl config get-contexts
     CURRENT   NAME       CLUSTER     AUTHINFO      NAMESPACE
               ckube      ckube-clu   ckube-admin
     *         ukube      ukube-clu   ukube-admin
     ```
  5. If you want multiple Ubuntu-based clusters to exist at the same time, then you must either
     explicitly set the IP address of the master node, or ensure that only one of the clusters is
     running at any given moment (to avoid IP address conflicts).
  6. Select context (project name) using
      ```
      $ kubectl config use-context <context-name>
      ```
  7. ez-kubeadm's default directory for storing kubeconfig files is $HOME/.kube/config.d. This can be
     over-ridden by using the "-o" option to makeK8s.sh.  The directory will be created if it does
     not exist.     
  8. I suggest adding the node names (master, node1, etc) to your hosts file.
     
     In Windows, these changes are applied to the native Windows hosts file -- not /etc/hosts in
     bash. The native Windows hosts file can be found at C:\Windows\system32\drivers\etc\hosts.
  9. When you are entirely finished with a cluster, you probably want the associated kubeconfig file
     to be deleted, along with the cluster, which can be accomplished as follows:
     ```
     source ./makeK8s.sh -d
     ```
     If the cluster is removed using, say "vagrant destroy -f", then the cluster will be destroyed,
     but the kubeconfig file will still exist.
  10. When the preferred host user account is created on the k8s master and nodes, the accounts password
      is set (needed for sudo).  The password is set to "qwerty0987".  Change it, when/if desired.
  11. By default, the master node's taint against running pods is removed. If you don't want pods to be
      scheduled on the master node, comment out, or remove, the line in Vagrantfile.centos/Vagrantfile.ubuntu.
  12. I like to ssh directly into the cluster from any directory on my host.  These scripts support this by
      pushing an SSH public key down to each node.

## WSL Notes (Windows 10's Linux environment):

My development and testing were initially performed on Ubuntu 18 (Bionic). I later ported it to 
Windows 10's WSL Ubuntu (bash) environment. Several changes were required to get things working on
WSL -- some in the Vagrantfiles, some in the Windows environment.  Thankfully, the required file
changes for WSL are compatible with native Ubuntu, so we don't need any Windows-specific files.

I've tried to capture all necessary steps here.
For more information, see: https://www.vagrantup.com/docs/other/wsl.html.

Specific env vars and for Windows WSL:
  1. Set your WSL project environment -- vagrant projects don't work when housed directly within
     the WSL filesystem (e.g. /home/$LOGNAME). I suggest basing your projects in, for example,
     /mnt/c/Users/<user>/projects, but use a symlink in a directory under your home directly,
     as suggested here:
       https://cepa.io/2018/02/20/linuxizing-your-windows-pc-part2/
     Let's make that more concrete:
       My username for both Windows and WSL is $LOGNAME; $HOME is /home/$LOGNAME; my projects
       directory in Windows is C:\Users\$LOGNAME\projects, where my vagrant project folders live.
       Assume that we want to access that directory from $HOME/projects. Use a symlink to
       accomplish this. Make the vagrant project folders accessible from my $HOME directory:
       ```
       ln -s /mnt/c/Users/$LOGNAME/projects $HOME/projects
       ```
  * Set the root path to your vagrant projects directory by exporting this env var, and append to .bashrc:
       ```
       echo "export VAGRANT_WSL_WINDOWS_ACCESS_USER_HOME_PATH=/home/$LOGNAME/projects" >>$HOME/.bashrc && source $HOME/.bashrc
       ```
  * set VAGRANT_WSL_ENABLE_WINDOWS_ACCESS to 1, and append to .bashrc
       ```
       echo "export VAGRANT_WSL_ENABLE_WINDOWS_ACCESS=1" >>$HOME/.bashrc && source $HOME/.bashrc
       ```
  * To avoid rsync and vagrant ssh problems (e.g. "error when attempting to rsync a synced folder":
       ```
       echo "export VAGRANT_HOME=\"/home/$LOGNAME/.vagrant.d\"" >>$HOME/.bashrc && source $HOME/.bashrc
       ```

  2. C:\Windows\System32\drivers\etc\hosts file permissions -- user must have modify permission
     to avoid "Permission denied" for the vagrant hostsupdater plugin to work (it's not installed by
     VBox 5.2.x, but is in VBox 6.0.)
  3. Mounted Windows partitions, e.g. C:, may ignore permissions set, for example, by chmod. Correct
     this by re-mounting the volume, specifying "-o metadata", viz.:
      ```
       $ sudo umount /mnt/c && sudo mount -t drvfs C: /mnt/c -o metadata
      ```
     Also, the files in /mnt/c may all be owned by root. Adjust as needed.
     See https://blogs.msdn.microsoft.com/commandline/2018/01/12/chmod-chown-wsl-improvements/
     See Also: https://docs.microsoft.com/en-us/windows/wsl/wsl-config
  4. VMs won't spin up on WSL due to weak permissions on the key-pair created by vagrant.  The solution is to add this
     line to the Vagrantfile:
     ```
     config.ssh.insert_key = false
     ```
     With this line present in the Vagrantfile, both CentOS and Ubuntu VMs will boot successfully.
  5. With permissions changes enabled from bash (via metadata), tighten any ssh key permissions to
     avoid problems: I set my PKI keys as "chmod 644 id_rsa*"
  6. vagrant is prone to throwing "Insecure world writable dir" errors. I tend to use
     "chmod 755 <dir>" to correct these, which seems to work fine.

That's it for the setup.  Here are some further WSL notes, which describe some issues I've
encountered; they have all been addressed by the files in our repo:
  1. There is a problem with some Ubuntu box versions on VM spinup:
        "rawfile#0 failed to create the raw output file VERR_PATH_NOT_FOUND".
     The error can be avoided by adding this line to the Vagrantfile:
       ```
       vb.customize [ 'modifyvm', :id, '--uartmode1', 'disconnected']
       ```
  2. I've observed no need to run as administrator -- neither bash, or VBox Manager
  3. When this group of files is pulled down from github, they may arrive as DOS-formatted files,
     which causes runtime errors.  Install and use dos2unix utility to modify the shell scripts, to
     correct.
  4. I've had problems with VMs (Xenial) booting extremely slowly with VBox 6.0, while v5.2.26
     works great. see https://github.com/hashicorp/vagrant/issues/10578, for a discussion of this
     issue.
  5. Another VBox 6.0 issue: Centos cluster VMs don't come up under VBox 6.0 either -- the master node
     boots fine, but the next VM (cnode1) fails to spin up.
  6. Side note on VBox 6.0: Windows UAC will trigger when the hostupdater (a vagrant plugin) tries
     to update the hosts file.
  7. In short, avoid VBox 6.0.
 
## Repo Files and Network Notes:

These are the files included in the repo:
  * makeK8s.sh           -- wrapper
  * Vagrantfiles         -- Vagrantfile.centos and Vagrantfile.ubuntu -- one of which is copied to
                            Vagrantfile at runtime.
  * post-k8s.sh          -- make account for host user on nodes, prepare to pull kube config file,
                            admin.conf
  * pull-k8s-admin.sh    -- download admin.conf from master, for use on host
  * modKubeConfigFile.sh -- process admin.conf file, extracting PKI data, massage naming, and save
                            in directory with other kubeconfig files
  * setKubeConfigVar.sh -- consolidate multi-cluster configs into KUBECONFIG env var
  
  The modified network CNI YAML files are included in this repository. They are:
  * canal2.yaml, canal2c.yaml -- canal2 for Ubuntu, canal2c for CentOS
  * kube-flannel.yaml, kube-flannelc.yaml
  * romana-kubeadm.yaml

These network CNI's all seem to work well -- feel free to use any of them.  Any quirks have been
addressed in the Vagrantfiles and YAML:
  * calico:    Simply works.
  * weave:     Worker nodes require a static route to the master node (applied by Vagrantfile)
  * romana:    Seems to require romana-agent daemonset tolerance for not-ready nodes
  * flannel:   Its yaml must be tweaked to use enp0s8(Ubuntu) or eth1(CentOS) host-only interface,
               not the NAT'd one
  * canal      Its yaml must be tweaked to use enp0s8(Ubuntu) or eth1(CentOS) host-only interface,
               not the NAT'd one

Calico and Weave need no YAML mods.
Weave, however, requires a route to be set for worker nodes to find the master (corrected in
Vagrantfile).
Canal, Flannel, and Romana require minor mods their YAML; e.g. use 2nd network adapter (enp0s8/eth1).

Romana curiously seems to present a catch-22: romana-agent won't install on "not-ready" nodes,
but the nodes can only become ready when romana-agent is up and running. My solution: add tolerance
for nodes that are not-ready (applied to the romana-agent daemonset YAML).

## SSH key handling

In building the worker nodes, We run a script on each of the nodes to scp the kubernetes join script
from the master node (where kubeadm places it, while building the master node).
This allows automation of the nodes joining the kubernetes cluster.

To use scp, we use the aforementioned key pair for the vagrant user on each of the nodes, in 
/home/vagrant/.ssh
On the master, we also need to add the vagrant pub-key into the master's authorized_keys file, in
/home/vagrant/.ssh/authorized_keys

Thankfully, the project directory is automatically mounted onto each node by Vagrant, at /vagrant.
Therefore, the SSH keys of interest are accessible by all our Vagrant VMs, at that location.

NOTE: The mount is only automatic during node creation, and must be re-mounted manually if the node
reboots (Note: mount can be made automatic).

