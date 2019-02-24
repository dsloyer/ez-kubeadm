# ez-kubeadm
Bash scripts, Vagrantfiles, YAML to easily create multi-node kubernetes clusters on a Windows or Linux-based
host via vagrant/VBox.  Select whether nodes are Ubuntu or CentOS via runtime parameter.  CNI network is selected via environment
variable -- one of {calico, canal, flannel, romana, weave}.

Following forking the repository, installation of applications, directory creation, and setting env variables, a complete
Kubernetes cluster based on Ubuntu, with Calico networking, can be built with a single command in the vagrant project directory:

Assuming you've downloaded the ez-kubeadm files in ~/projects/ez-kubeadm, and are cd'd into ~/projects, these are the commands to build a working Ubuntu-based cluster in ~/projects/kube in 10-15 minutes:

```
$ cd ~/projects
$ mkdir kube
$ cd kube
$ vagrant init
$ cp ../ez-kubeadm/* .
$ cp ~/.ssh/id_rsa.pub id_rsa.pub.$LOGNAME
$ source ./makeK8s.sh -s ubuntu

... a couple of thousand lines of text, and 15 minutes, later...

$ kubectl config use-context kube
Switched to context "kube".
$ kubectl get nodes
NAME     STATUS   ROLES    AGE     VERSION
master   Ready    master   10m     v1.13.3
node1    Ready    <none>   7m12s   v1.13.3
node2    Ready    <none>   2m28s   v1.13.3

... with the nodes manually added to /etc/hosts (or C:\Windows\System32\drivers\etc\hosts), and my public key
    installed (by makeK8s.sh) on all nodes, I can easily ssh to nodes by name, and from any directory on my host:

$ cd ~/test
$ ssh master
Warning: Permanently added the ECDSA host key for IP address '192.168.205.10' to the list of known hosts.
Welcome to Ubuntu 16.04.6 LTS (GNU/Linux 4.4.0-142-generic x86_64)
 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/advantage
  Get cloud support with Ubuntu Advantage Cloud Guest:
    http://www.ubuntu.com/business/services/cloud

0 packages can be updated.
0 updates are security updates.

New release '18.04.2 LTS' available.
Run 'do-release-upgrade' to upgrade to it.

*** System restart required ***
To run a command as administrator (user "root"), use "sudo <command>".
See "man sudo_root" for details.

username@master:~$
```
Destroy the cluster by cd'ing into the project folder for the cluster, then run:
```
$ vagrant destroy -f
```

To use CentOS and Flannel instead:
```
$ export k8snet=flannel
$ source ./makeK8s.sh -s centos
```

I've had several issues with VirtualBox 6.0 -- I strongly recommend using 5.2.26 at this time.
After hammering out issues with WSL, I'm satisfied that that environment is as good as the
native Ubuntu under which these scripts were developed.  That said, see notes below.

As of mid-Feb, 2019, this script creates a 3-node k8s cluster, with these versions:
  * Kubernetes: 1.13.3                          (current version on kubernetes.io)
  * Docker:     18.06.2                         (prescribed by kubernetes.io)
  * Centos:     CentOS7,                        (prescribed by kubernetes.io))
    * Version:  1901.01                         (latest CentOS7 box from Vagrant)
  or
  * Ubuntu:     Ubuntu/xenial64                 (prescribed by kubernetes.io)
    * Version   20190215.0.0                    (latest Ubuntu Xenial box from Vagrant)

## Setup (Linux and Windows hosts):
  1. Install VirtualBox and vagrant on your host system (my host is Ubuntu Bionic Beaver, which
     was used to test all of this
  2. Create a project directory; cd to the project directory
  3. Run vagrant init
  4. Cluster network is calico, by default. To change, export an env var, $k8snet, setting it to
     one of: calico, canal, flannel, romana, weave
  5. We assume kube config files are gathered together in a directory, ~/.kube/config.d, on the host. You'll get an
     error if the directory does not exist, or another is not specified as an argument to makeK8s.sh.
  6. Pull the collection of files from github into the project directory:
       * makeK8s.sh (one script to rule them all, and in the darkness bind them (LOTR))
       * Vagrantfiles (Vagrantfile.centos and Vagrantfile.ubuntu -- one of which is copied to Vagrantfile at runtime.
       * post-k8s.sh (make account for host user on nodes, prepare to pull kube config file, admin.conf)
       * pull-k8s-admin.sh (download admin.conf from master, for use on host)
       * modKubeConfigFile.sh (process admin.conf file, for 
       * setKubeConfigVar.sh (consolidate multi-cluster configs into KUBECONFIG env var)
       * copy public key for a desired host user account. E.g., I am on my host, and want to ssh
         to any node as <username>. I copy my id_rsa.pub file into the vagrant project directory, for scripted
         install on nodes

       Network files (tweaked for vagrant/VBox, Ubuntu and CentOS).
       Calico and Weave need no YAML mods. Weave, however, requires a route to be set for worker nodes to find the master.
       Canal, Flannel, and Romana require minor mods their YAML; e.g. use 2nd network adapter (enp0s8/eth1).
       The modified YAML files are included in this repository. They are:
       * canal2.yaml, canal2c.yaml (canal2 for Ubuntu, canal2c for CentOS),
       * kube-flannel.yaml, kube-flannelc.yaml, and
       * romana-kubeadm.yaml

       Romana curiously seems to present a catch-22: romana-agent won't install on "not-ready" nodes,
       but the nodes can only become ready when romana-agent is up and running. My solution: add tolerance for
       nodes that are not-ready (applied to the romana-agent daemonset YAML).
  7. Run "source ./makeK8s.sh -s ubuntu", or "source ./makeK8s.sh -s centos" to create a new cluster
  8. Edits to the Vagrantfile should only be needed to:
      * change the memory or CPU settings for the nodes
      * change master and worker node IP addresses.
        Ubuntu master IP is 192.168.205.10; worker node IPs immediately follow, i.e. node1 is 192.168.205.11
        CentOS cmaster IP is 192.168.205.15; worker node IPs immediately follow, i.e. cnode1 is 192.168.205.16
      * want more/fewer nodes? edit the relevant servers array, below.
  9. Install kubectl on your host system, per instructions on kubernetes.io
     One method (https://kubernetes.io/docs/tasks/tools/install-kubectl/):
       ```
       curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
       ```
     Make it executable (chmod +x) and move to a preferred directory in your path, e.g. /usr/local/bin.
  10. To set the KUBECONFIG env var at any time, on any shell, cd to the project directory, and "source" the
  script "setKubeConfigVar.sh":
     ```
     $ source ./setKubeConfigVar.sh
     ```
  11. Only one context can be active at a time, across multiple shells.
  12. Select context (project name) using
      ```
      $ kubectl config use-context <context-name>
      ```
  13. View configs using
      ```
      $ kubectl config view
      ```
  14. I suggest adding the node names (master, node1, etc) to your hosts file.
  
## WSL Notes (running these scripts on Windows 10's Linux environment):
My development and testing were initially performed on Ubuntu 18 (Bionic). I later ported it to 
Windows 10's WSL (bash) environment (Ubuntu).
There were quite a number of changes required to get things working on Windows.
I've tried to capture all necessary steps here. I suggest reviewing: https://www.vagrantup.com/docs/other/wsl.html.
Replace <user> with your preferred host user account. Replace <projects> with a directory of your choosing.

  1. Install Windows version of VirtualBox -- 5.2.x.  VBox 6.0 gave me headaches that could be resolved.
  2. Add VirtualBox binaries to system PATH
       System->Properties->Adv System Settings->Environment Variables...->System variables
     The VirtualBox path is typically c:\Program Files\Oracle\VirtualBox
  3. Install vagrant for Linux in WSL bash.  I used 
       wget https://releases.hashicorp.com/vagrant/2.2.3/vagrant_2.2.3_x86_64.deb
     Then sudo apt-get install ./vagrant_2.2.3_x86_64.deb (because Ubuntu is Debian-based, and uses apt).
     NOTE: apt update from Windows bash seems to give older version; I opted for the latest.
  4. vagrant projects don't work well from /home/<user>. Base your projects in, for example, /mnt/c/Users/<user>/projects,
     but use a symlink in a directory under your home directly, as suggested here:
       https://cepa.io/2018/02/20/linuxizing-your-windows-pc-part2/
     Let's make that more concrete:
       My username is <user>; $HOME is /home/<user>; my projects directory in Windows is
       C:\Users\<user>\<projects>, where my vagrant project folders live. Assume that we want to access 
       that directory from $HOME/<projects>. Use a symlink to accomplish this.
       Make the vagrant project folders accessible from my $HOME directory:
       ```
       cd $HOME
       ln -s /mnt/c/Users/<user>/<projects> <projects>
       ```
       Set the root path to your vagrant projects directory by exporting this env var (and append to .bashrc):
       ```
       export VAGRANT_WSL_WINDOWS_ACCESS_USER_HOME_PATH=/home/<user>/<projects>
       ```
  5. export VAGRANT_WSL_ENABLE_WINDOWS_ACCESSS=1, and append to .bashrc
     ```
     export VAGRANT_WSL_ENABLE_WINDOWS_ACCESSS=1
     echo "export VAGRANT_WSL_ENABLE_WINDOWS_ACCESSS=1" >>~/.bashrc
     ```
  6. To avoid rsync and vagrant ssh problems (e.g. "error when attempting to rsync a synced folder":
     ```
     export VAGRANT_HOME="/home/<user>/.vagrant.d"
     ```
     Note: In Vagrantfile, I've added this line to avoid another rsync issue: config.ssh.insert_key = false
  7. There is a problem with Ubuntu/Xenial on VM spinup: "rawfile#0 failed to create the raw output file VERR_PATH_NOT_FOUND".
     The error can be avoided by adding this line to the Vagrantfile:
       vb.customize [ 'modifyvm', :id, '--uartmode1', 'disconnected']
  8. C:\Windows\System32\drivers\etc\hosts file permissions -- user must have modify permission
     to avoid "Permission denied" for the vagrant hostsupdater plugin to work (it's not installed by
     VBox 5.2.x, but is in VBox 6.0.
  9. no need to run as administrator -- neither bash, or VBox
  10. When this group of files is pulled down from github, they may arrive as DOS-formatted files, which
     causes runtime errors.  Install and use dos2unix utility to modify the shell scripts, to correct.
  11. Mounted Windows partitions, e.g. C:, may ignore permissions set, for example, by chmod. Correct this
      by re-mounting the volume, specifying "-o metadata", viz.:
       "sudo umount /mnt/c && sudo mount -t drvfs C: /mnt/c -o metadata"
      Also, the files in /mnt/c may all be owned by root. Adjust as needed.
      For more, see https://blogs.msdn.microsoft.com/commandline/2018/01/12/chmod-chown-wsl-improvements/
      Also: https://docs.microsoft.com/en-us/windows/wsl/wsl-config
  12. With permissions changes enabled from bash (via metadata), tighten any ssh key permissions to avoid
      problems: I set my keys as "chmod 644 id_rsa*"
  13. I've had problems with VMs (Xenial) booting extremely slowly with VBox 6.0, while v5.2.26 works great.
      see https://github.com/hashicorp/vagrant/issues/10578, for a discussion of this issue.
  14. Another VBox 6.0 issue: Centos cluster VMs don't come up under VBox 6.0 either -- the master node
      boots fine, but the next VM fails to spin up. I've not yet found similar reports from others.
  15. Side note on VBox 6.0: UAC will trigger when the hostupdater (a vagrant plugin) tries to update
      the hosts file. Not sure how necessary this plugin is -- installed on v6.0 by default, consider
      removing it via "vagrant plugin remove".

## Network Notes:
These all work -- feel free to use any of them.  Any quirks have been addressed in the Vagrantfiles and YAML:
  * calico:    Simply works.
  * weave:     Worker nodes require a static route to the master node.
  * romana:    Seems to require romana-agent daemonset tolerance for not-ready nodes
  * flannel:   Its yaml must be tweaked to use enp0s8(Ubuntu) or eth1(CentOS) host-only interface, not the NAT'd one
  * canal      Its yaml must be tweaked to use enp0s8(Ubuntu) or eth1(CentOS) host-only interface, not the NAT'd one

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
of files in /vagrant often go unseen, and may be lost. It's not a file server!

