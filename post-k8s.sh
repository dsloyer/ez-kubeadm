#!/bin/bash
# Apply this script on node, as user vagrant, from /vagrant vol (project directory mounted on the VMs)

# this host account is to be enabled on all kubernetes nodes.
# NOTE: the user on each node now has credentials, but no password.  Can ssh to node, but not sudo, as a result.
echo NEWUSER: $NEWUSER
user=${NEWUSER}
echo user: $user

isCentOS=0
isUbuntu=0

# Gather the Linux distro name
LINVER=`awk -F= '/^NAME/{print $2}' /etc/os-release`
# Now, strip the quotes away
LINVER=`sed -e 's/^"//' -e 's/"$//' <<<"$LINVER"`
# LINVER is now likely to be either "Ubuntu" or "CentOS Linux" (sans quotes)
echo LINVER: $LINVER

if [[ $LINVER = "CentOS Linux" ]]; then
   isCentOS=1
   echo isCentOSr: "$isCentOS"
elif [[ $LINVER = "Ubuntu" ]]; then
   isUbuntu=1
   echo isUbuntu: "$isUbuntu"
else
   echo WARNING: Unexpected operating system: $LINVER
fi

# Install vim on CentOS (it's built-in on Ubuntu)
if [[ $isCentOS -eq 1 ]]; then
   sudo yum install -y vim
fi

# create user on each node, to support remote access to node from host
# Later, delete using "userdel -r user

# check whether user already exists
id -u $user >/dev/null 2>&1
if [[ $? -eq 0 ]]; then
   echo User, $user, already exists
else
   echo Adding user, $user
   sudo useradd $user -d /home/$user
   if [[ $? -ne 0 ]]; then
      echo ERROR adding user, $user
      exit 1
   fi
fi

# set password to qwerty0987
sudo echo -e "qwerty0987\nqwerty0987" | sudo passwd $user

if [[ $isCentOS -eq 1 ]]; then
   # On CentOS, wheel group is sudo-enabled
   echo "Add user, $user, to group, wheel"
   sudo usermod -aG wheel $user

   # # CentOS home directory permissions
   # sudo chmod 700 /home/$user
elif [[ $isUbuntu -eq 1 ]]; then
  # Create /home/$user directory for new user, as needed
  if [[ -d /home/$user ]]; then
    echo /home/$user exists.
  else
    mkdir sudo mkdir /home/$user
    if [[ -d /home/$user ]]; then
       echo Successfully created /home/$user directory
    else
       echo ERROR: Error creating directory, /home/$user
       exit 1
    fi
  fi

  # Set ownership of the home directory to the user and his group
  sudo chown $user:$user /home/$user

  # Ubuntu home directory permissions
  sudo chmod 755 /home/$user

  echo "Adding user, $user, to group, sudo"
  # On Ubuntu, sudo group is sudo-enabled
  sudo usermod -aG sudo $user
fi

echo "set default shell for user, $user, to bash"
sudo usermod -s /bin/bash $user

# create .ssh directory and authorized_keys file, with correct ownership and permissions
if [[ -d /home/$user/.ssh ]]; then
  echo /home/$user/.ssh exists.
else
  sudo mkdir /home/$user/.ssh
fi

echo "copy $user's .profile, .bashrc, and .vimrc to node"
# these files were placed in /tmp during vagrant VM provisioning
sudo chown -R $user:$user /tmp
# sudo mv /tmp/.profile /home/$user
# sudo mv /tmp/.bashrc  /home/$user
sudo cp /tmp/.vimrc   /home/vagrant
sudo mv /tmp/.vimrc   /home/$user

# enable kubectl completion on each node
echo make kubectl completion permanent for $user, appending to .bashrc
echo "source <(kubectl completion bash)" >>~/.bashrc

# copy $user public key to node
echo copy $user public key to master to support authentication of $user from host
sudo cp /vagrant/id_rsa.pub.$user /home/$user/.ssh/authorized_keys
echo assign ownership to $user
sudo chown $user:$user /home/$user/.ssh/authorized_keys
sudo chown $user:$user /home/$user/.ssh
echo set permissions to .ssh and authorized_keys
sudo chmod 600 /home/$user/.ssh/authorized_keys
sudo chmod 700 /home/$user/.ssh

# Prep the cluster's admin.conf file for later retrieval
if [[ -f /etc/kubernetes/admin.conf ]]; then
  echo "Found: /etc/kubernetes/admin.conf (I must be running on the master)"
  echo "Copy admin.conf file to $user\'s home directory"
  echo "Later, after cluster deployment is complete, use scp to pull"
  echo "the admin.conf file down to the host machine, for use in"
  echo "kubectl authentication"
  sudo cp /etc/kubernetes/admin.conf /home/$user
  # set ownership
  echo set ownership and permissions for the copied file
  sudo chown $user:$user /home/$user/admin.conf
  sudo chmod 777 /home/$user/admin.conf

  echo "copy kube config file from /home/$user to .kube directory", for local kubectl
  sudo mkdir /home/$user/.kube
  sudo chown $user:$user /home/$user/.kube
  cp /home/$user/admin.conf /home/$user/.kube/config
else
  echo File not found: /etc/kubernetes/admin.conf
fi

# test:
# at host, scp the admin.conf file from the master
# at host, "kubectl --kubeconfig ./admin.conf get nodes" should now work
# Nicht vergessen: user still needs a password on each node.
# One solution: "vagrant ssh <node>", then "sudo passwd <user>".
# Another issue: because we've used "useradd" rather than "adduser", the
# shell, profile, and probably some other items are not yet setup.  We
# can run "chsh -s /bin/bash <user>", and copy .bashrc from /etc/skel, etc.
