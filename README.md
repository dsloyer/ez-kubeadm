# Spin Up Multi-node Kubernetes Clusters In One Simple Command

I wanted to be able to create, and recreate, various Kubernetes clusters on demand, in my local environment,
with a single command -- an exercise in Infrastructure as Code (IaC). I also wanted to support several clusters,
and support easy switching between them.

Following the thread of development in pursuit of these goals has led to this collection of files -- Bash scripts,
Vagrantfiles, and YAML files -- which achieve the initial goal.  First implemented on a vintage laptop running
Ubuntu Linux, I extended the project to also include Windows WSL on a newer laptop.

All the files that comprise this project are in http://github.com/dsloyer/ez-kubeadm

* Kubeadm is the tool used to deploy the cluster.
* Vagrant installs and configures the Ubuntu/CentOS boxes on VirtualBox.
* Bash scripts manage the process, perform further operations on the cluster nodes, providing a seamless experience.
* To better support multiple kubernetes configurations, we modify the kubeconfig files, gather them in a single
  directory, and set the KUBECONFIG env var based on the contents of that directory.
* I like to ssh directly into the cluster from any directory on my host, which is enabled by pushing an SSH public
  key down to each node.

The Kubernetes master and worker node VMs can be either Ubuntu (by default; CentOS is easily selected via runtime
parameter).

Currently supporting any of five networking alternatives, a CNI network is selected via environment variable -- 
one of {calico, canal, flannel, romana, weave}.  Calico is deployed by default.  You may not care what network is
being used -- I included them as an exercise for me.  If you're interested in exploring, for example, network policies,
you may find one network, or another, to be of interest.

A complete Kubernetes cluster based on Ubuntu, with Calico networking, can be built with a single command in the
vagrant project directory. Before running that command, you first must do some modest preparation:
  1. clone this repository locally (into, say $HOME/projects/ez-kubeadm)
  2. install vagrant and VirtualBox
  3. setup directories and env variables. All this is described in detail, below.

Assuming you've setup your system per the instructions below, a few simple steps prepare for an entirely new cluster.
Let's call it 'ukube':
```
$ cd $HOME/projects
$ mkdir ukube && cd ukube
$ vagrant init
$ cp ../ez-kubeadm/* .
$ cp $HOME/.ssh/id_rsa.pub id_rsa.pub.$LOGNAME
```
You're ready to create a cluster, or destroy and recreate an Ubuntu-based Kubernetes cluster, anytime, from this directory,
with a single command:
```
$ source ./makeK8s.sh
```
About 10 minutes later, the cluster is up and ready to use:
```
$ kubectl config use-context ukube
Switched to context "ukube".
$ kubectl get nodes
NAME     STATUS   ROLES    AGE     VERSION
master   Ready    master   5m41s   v1.13.4
node1    Ready    <none>   3m8s    v1.13.4
node2    Ready    <none>   21s     v1.13.4                                                                             
```
Let's change directory, spin up a BusyBox container on each node as a daemonset (ds-bb.yaml not shown here), ssh
to the master node, and list the running pods:
```
$ cd $HOME/test
$ kubectl create -f ds-bb.yaml
daemonset.apps/bb created

$ ssh master
The authenticity of host 'master (192.168.205.10)' can't be established.
ECDSA key fingerprint is SHA256:lHvDa0Gg2wnjGeD7rmXWw5ltSGzc8OCnewi9xJpDfXE.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added 'master' (ECDSA) to the list of known hosts.
Welcome to Ubuntu 16.04.6 LTS (GNU/Linux 4.4.0-142-generic x86_64)
--- some text removed ---

username@master:~$ kubectl get po -o wide
NAME       READY   STATUS    RESTARTS   AGE   IP            NODE     NOMINATED NODE   READINESS GATES
bb-2jc26   1/1     Running   0          32s   192.168.0.5   master   <none>           <none>
bb-7xhkx   1/1     Running   0          32s   192.168.1.3   node1    <none>           <none>
bb-d684p   1/1     Running   0          32s   192.168.2.4   node2    <none>           <none>
```
Destroy the cluster by cd'ing into the project folder for the cluster, then run:
```
$ cd $HOME/projects/ukube
$ vagrant destroy -f
```

To create a cluster built from CentOS and Flannel networking:
```
$ export k8snet=flannel
$ source ./makeK8s.sh -s centos
```

I've had several issues with VirtualBox 6.0 -- I strongly recommend using 5.2.26 at this time.

As of mid-March, 2019, this script creates a 3-node k8s cluster (master and 2 worker nodes), with these versions:
  * Kubernetes: 1.13.4                          (current version on kubernetes.io)
  * Docker:     18.06.2                         (prescribed by kubernetes.io)
  * Centos:     CentOS7,                        (prescribed by kubernetes.io))
    * Version:  1902.01                         (latest CentOS7 box from Vagrant)
  or
  * Ubuntu:     Ubuntu/xenial64                 (prescribed by kubernetes.io)
    * Version   20190308.0.0                    (latest Ubuntu Xenial box from Vagrant)

## Setup Instructions:
  1. Install kubectl on your host system, per instructions on kubernetes.io
     One method (https://kubernetes.io/docs/tasks/tools/install-kubectl/):
       ```
       $ curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
       $ chmod +x kubectl
       $ mv kubectl /usr/local/bin
       ```
     Make it executable and move to a preferred directory in your path, e.g. /usr/local/bin, as seen above
  2. Install VirtualBox 5.2.6 for your system.  On Linux, install VirtualBox for Linux. For Windows WSL, install the Windows
     version, not the Linux version.  NOTE: We assume you've enabled virtualization in the BIOS, and that no competing
     virtualization schemes have been enabled (e.g. Windows Hyper-V)
  3. (WSL only) Add VirtualBox binaries to System PATH, found at
       System->Properties->Adv System Settings->Environment Variables...->System variables
     The VirtualBox path is typically c:\Program Files\Oracle\VirtualBox, which you append to the System PATH.
  4. Install vagrant for Linux in bash (both Linux and Windows WSL). I used
     ```
     $ wget https://releases.hashicorp.com/vagrant/2.2.3/vagrant_2.2.3_x86_64.deb
     $ sudo apt-get install ./vagrant_2.2.3_x86_64.deb
     ```
  5. We assume you have a projects directory, e.g. $HOME/projects.
  
     WSL only: as discussed below, it's a good idea to locate the projects directory in, e.g., C:\Users\\$LOGNAME\projects,
     set env vars also listed here, and specify metadata on the mounted C: drive:
     ```
     $ ln -s /mnt/c/Users/$LOGNAME/projects $HOME/projects
     $ export VAGRANT_WSL_WINDOWS_ACCESS_USER_HOME_PATH=/home/$LOGNAME/projects
     $ echo "VAGRANT_WSL_WINDOWS_ACCESS_USER_HOME_PATH=/home/$LOGNAME/projects" >>$HOME/.bashrc
     $ export VAGRANT_WSL_ENABLE_WINDOWS_ACCESS=1
     $ echo "export VAGRANT_WSL_ENABLE_WINDOWS_ACCESS=1" >>$HOME/.bashrc
     $ export VAGRANT_HOME="$HOME/.vagrant.d"
     $ sudo umount /mnt/c && sudo mount -t drvfs C: /mnt/c -o metadata
     ```
  6. Create a new directory, ez-kubeadm, in your projects directory, to hold the ez-kubeadm repo files, and populate it
     with the files from this repo.
  7. Create a project directory specific to each kubernetes cluster you wish to keep; e.g. $HOME/projects/ukube/, and ckube/
     (one for an Ubuntu cluster, another for CentOS).
  8. Accept ez-kubeadm's default directory for kubeconfig files -- $HOME/.kube/config.d. This can be over-ridden
     by using the "-o" option to makeK8s.sh. If you accept the default directory, create it:
     ```
     $ mkdir $HOME/.kube/config.d
     ```
  9. cd to the specific kubernetes cluster project directory, e.g. $HOME/projects/ukube
  10. Run "vagrant init"
      ```
      $ vagrant init
      ```
  11. Copy the collection of files from this repo into the project directory
      ```
      $ cp ../ez-kubeadm/* .
      ```
  12. Copy your id_rsa.pub file into the vagrant project folder (if needed, use "ssh-keygen -t rsa -b 4096 -f id_rsa" in
      $HOME/.ssh)
      ```
      $ cp $HOME/.ssh/id_rsa.pub id_rsa.pub.$LOGNAME
      ```
  13. Check the CPU/memory settings in the relevant Vagrantfile -- either Vagrantfile.ubuntu, or Vagrantfile.centos.
      Preferring Ubuntu, I've set RAM on Ubuntu nodes to 4096MB, while Centos nodes get only 2048MB, unless changed
      in the Vagrantfile.
  14. Run "source ./makeK8s.sh", or "source ./makeK8s.sh -s centos" to create a new cluster
  
NOTES  
  1. Edits to the Vagrantfile (Vagrantfile.ubuntu or Vagrantfile.centos) should only be needed to:
     * change the memory or CPU settings for the nodes
     * change master and worker node IP addresses.
       Ubuntu master IP is 192.168.205.10; worker node IPs immediately follow, i.e. node1 is 192.168.205.11
       CentOS cmaster IP is 192.168.205.15; worker node IPs immediately follow, i.e. cnode1 is 192.168.205.16
     * want more/fewer nodes? edit the servers array in the Vagrantfile.

  2. To set the KUBECONFIG env var at any time, on any shell, cd to the project directory, and "source" the
     script "setKubeConfigVar.sh":
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
               minikube   minikube    minikube
     *         ukube      ukube-clu   ukube-admin
     ```
  5. Select context (project name) using
      ```
      $ kubectl config use-context <context-name>
      ```
  6. I suggest adding the node names (master, node1, etc) to your hosts file. Actually, the some of the
     bash script logic depends on it.
     
     In Windows, these changes are applied to the native Windows hosts file -- not /etc/hosts in bash.
     The native Windows hosts file can be found at C:\Windows\system32\drivers\etc\hosts.
  
## WSL Notes (running these scripts on Windows 10's Linux environment):

My development and testing were initially performed on Ubuntu 18 (Bionic). I later ported it to 
Windows 10's WSL Ubuntu (bash) environment.

There were serveral changes required to get things working on WSL -- some in the Vagrantfiles, some in the
Windows environment.  Thankfully, the required file changes for WSL are compatible with native Ubuntu, so
we don't need any Windows-specific files.

I've tried to capture all necessary steps here. I suggest reviewing: https://www.vagrantup.com/docs/other/wsl.html.

Specific env vars and for Windows WSL:
  1. Set your WSL project environment -- vagrant projects don't work well from /home/<user>. I suggest basing
     your projects in, for example, /mnt/c/Users/<user>/projects, but use a symlink in a directory under your
     home directly, as suggested here:
       https://cepa.io/2018/02/20/linuxizing-your-windows-pc-part2/
     Let's make that more concrete:
       My username is in $LOGNAME; $HOME is /home/$LOGNAME; my projects directory in Windows is
       C:\Users\$LOGNAME\projects, where my vagrant project folders live. Assume that we want to access 
       that directory from $HOME/projects. Use a symlink to accomplish this.
       Make the vagrant project folders accessible from my $HOME directory:
       ```
       ln -s /mnt/c/Users/$LOGNAME/projects $HOME/projects
       ```
  * export VAGRANT_WSL_WINDOWS_ACCESS_USER_HOME_PATH, and append to .bashrc
       Set the root path to your vagrant projects directory by exporting this env var (and append to .bashrc):
       ```
       export VAGRANT_WSL_WINDOWS_ACCESS_USER_HOME_PATH=/home/$LOGNAME/projects
       echo "VAGRANT_WSL_WINDOWS_ACCESS_USER_HOME_PATH=/home/$LOGNAME/projects" >>$HOME/.bashrc
       ```
  * export VAGRANT_WSL_ENABLE_WINDOWS_ACCESS, and append to .bashrc
     ```
     export VAGRANT_WSL_ENABLE_WINDOWS_ACCESS=1
     echo "export VAGRANT_WSL_ENABLE_WINDOWS_ACCESS=1" >>$HOME/.bashrc
     ```
  * To avoid rsync and vagrant ssh problems (e.g. "error when attempting to rsync a synced folder":
     ```
     export VAGRANT_HOME="/home/$LOGNAME/.vagrant.d"
     ```
     Note: In Vagrantfile, I've added this line to avoid another rsync issue: config.ssh.insert_key = false
  2. C:\Windows\System32\drivers\etc\hosts file permissions -- user must have modify permission
     to avoid "Permission denied" for the vagrant hostsupdater plugin to work (it's not installed by
     VBox 5.2.x, but is in VBox 6.0.)
  3. Mounted Windows partitions, e.g. C:, may ignore permissions set, for example, by chmod. Correct this
      by re-mounting the volume, specifying "-o metadata", viz.:
      ```
       $ sudo umount /mnt/c && sudo mount -t drvfs C: /mnt/c -o metadata
      ```
      Also, the files in /mnt/c may all be owned by root. Adjust as needed.
      For more, see https://blogs.msdn.microsoft.com/commandline/2018/01/12/chmod-chown-wsl-improvements/
      Also: https://docs.microsoft.com/en-us/windows/wsl/wsl-config
  4. With permissions changes enabled from bash (via metadata), tighten any ssh key permissions to avoid
      problems: I set my keys as "chmod 644 id_rsa*"

That's it for the setup.  Here are some further WSL notes, which describe some issues I've encountered;
they have all been addressed by the files in our repo:
  1. There is a problem with some Ubuntu box versions on VM spinup:
        "rawfile#0 failed to create the raw output file VERR_PATH_NOT_FOUND".
     The error can be avoided by adding this line to the Vagrantfile:
       ```
       vb.customize [ 'modifyvm', :id, '--uartmode1', 'disconnected']
       ```
  2. I've observed no need to run as administrator -- neither bash, or VBox Manager
  3. When this group of files is pulled down from github, they may arrive as DOS-formatted files, which
     causes runtime errors.  Install and use dos2unix utility to modify the shell scripts, to correct.
  4. I've had problems with VMs (Xenial) booting extremely slowly with VBox 6.0, while v5.2.26 works great.
      see https://github.com/hashicorp/vagrant/issues/10578, for a discussion of this issue.
  5. Another VBox 6.0 issue: Centos cluster VMs don't come up under VBox 6.0 either -- the master node
      boots fine, but the next VM (cnode1) fails to spin up.
  6. Side note on VBox 6.0: Windows UAC will trigger when the hostupdater (a vagrant plugin) tries to update
      the hosts file.
  7. In short, avoid VBox 6.0.
 
## Repo Files and Network Notes:

These are the files included in the repo:
  * makeK8s.sh (one script to rule them all, and in the darkness bind them (LOTR))
  * Vagrantfiles (Vagrantfile.centos and Vagrantfile.ubuntu -- one of which is copied to Vagrantfile at runtime.
  * post-k8s.sh (make account for host user on nodes, prepare to pull kube config file, admin.conf)
  * pull-k8s-admin.sh (download admin.conf from master, for use on host)
  * modKubeConfigFile.sh (process admin.conf file, for 
  * setKubeConfigVar.sh (consolidate multi-cluster configs into KUBECONFIG env var)
  * copy public key for a desired host user account. E.g., I am on my host, and want to ssh
    to any node as <username>. I copy my id_rsa.pub file into the vagrant project directory, for scripted
    install on nodes
  The modified network CNI YAML files are included in this repository. They are:
  * canal2.yaml, canal2c.yaml (canal2 for Ubuntu, canal2c for CentOS),
  * kube-flannel.yaml, kube-flannelc.yaml, and
  * romana-kubeadm.yaml

These network CNI's all seem to work well -- feel free to use any of them.  Any quirks have been addressed in the
Vagrantfiles and YAML:
  * calico:    Simply works.
  * weave:     Worker nodes require a static route to the master node (applied by Vagrantfile)
  * romana:    Seems to require romana-agent daemonset tolerance for not-ready nodes
  * flannel:   Its yaml must be tweaked to use enp0s8(Ubuntu) or eth1(CentOS) host-only interface, not the NAT'd one
  * canal      Its yaml must be tweaked to use enp0s8(Ubuntu) or eth1(CentOS) host-only interface, not the NAT'd one

Calico and Weave need no YAML mods.
Weave, however, requires a route to be set for worker nodes to find the master (corrected in Vagrantfile).
Canal, Flannel, and Romana require minor mods their YAML; e.g. use 2nd network adapter (enp0s8/eth1).

Romana curiously seems to present a catch-22: romana-agent won't install on "not-ready" nodes,
but the nodes can only become ready when romana-agent is up and running. My solution: add tolerance for
nodes that are not-ready (applied to the romana-agent daemonset YAML).

## SSH key handling

In building the worker nodes, We run a script on each of the nodes to scp the kubernetes join script
from the master node (where kubeadm places it, while building the master node).
This allows automation of the nodes joining the kubernetes cluster.

To use scp, we use the aforementioned key pair for the vagrant user on each of the nodes,
in /home/vagrant/.ssh
On the master, we also need to add the vagrant pub-key into the master's authorized_keys file, in
/home/vagrant/.ssh/authorized_keys

Thankfully, the project directory is automatically mounted onto each node by Vagrant, at /vagrant.
Therefore, the SSH keys of interest are accessible by all our Vagrant VMs, at that location.
I should add, however, that the contents of that directory are not well-synced, so changes to contents
of files in /vagrant often go unseen, and may be lost.
NOTE: The mount is only automatic during node creation, and must be re-mounted manually if the node reboots.
