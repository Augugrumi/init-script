#!/bin/bash

. <(curl -s https://raw.githubusercontent.com/Polpetta/minibashlib/master/minibashlib.sh)
mb_load "logging"

function validateIP() {
  if [[ $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo 0
  else
    echo 1
  fi
}

function load_kernel_modules() {
    sudo sh -c 'modprobe dm_snapshot && modprobe dm_mirror && modprobe dm_thin_pool'
}

function label_nodes() {
  read -a slaves <<< $(nova list | tail -n+2 | grep -v master | cut -d" " -f1)
  for i in ${slaves[@]}
  do
    kubectl label node $i storagenode=glusterfs
  done
}

function allow_root_ssh() {
  sudo sed -i '1s/^/# /' /root/.ssh/authorized_keys && sudo sed -i 's/ssh-rsa/\'$'\nssh-rsa/g' /root/.ssh/authorized_keys
  sudo sed -i '/^#PermitRootLogin yes/s/^#//' /etc/ssh/sshd_config
  sudo systemctl restart sshd
}

# default values
ips=()
branch="master"
port=10243
toExit=0

# catch arguments passed
while getopts ":a:b:p:" opt; do
        case $opt in
            a)
                valid=$(validateIP $OPTARG)
                if [ "$valid" -eq 0 ]; then
                  ips+=("$OPTARG")
                else
                  msg err "Invalid IP address: -$OPTARG" >&2
                  toExit=1
                fi
                ;;
            b)
                branch="$OPTARG"
                ;;
            p)
                port="$OPTARG"
                ;;
            \?)
                msg err "Invalid option: -$OPTARG" >&2
                toExit=1
                ;;
            :)
                msg err "Option -$OPTARG requires an argument." >&2
                toExit=1
                ;;
        esac
done

# install glusterd on slave and git and python on master
toWait=()
for ((i=0; i<${#ips[@]}; i++))
do
  if [[ $i -eq 0 ]]
  then
    ssh -i kp- -oStrictHostKeyChecking=no centos@${ips[$i]} "sudo yum install -y git" &
    toWait+=($!)
  else
    ssh -i kp- -oStrictHostKeyChecking=no centos@${ips[$i]} "sudo yum install -y centos-release-gluster glusterfs-server glusterfs-fuse" &
    toWait+=($!)
  fi
done

for i in ${toWait[@]}
do
    wait $i
done

# start glusterd ONLY ON SLAVES
for ((i=1; i<${#ips[@]}; i++))
do
  ssh -i kp- -oStrictHostKeyChecking=no centos@${ips[$i]} "sudo systemctl start glusterd && sudo systemctl enable glusterd"
done

# start kernel modules ONLY ON SLAVES
for ((i=1; i<${#ips[@]}; i++))
do
  ssh -i kp- -oStrictHostKeyChecking=no centos@${ips[$i]} "$(typeset -f load_kernel_modules); load_kernel_modules"
done

# label SLAVES as storage nodes
ssh -i kp- -oStrictHostKeyChecking=no centos@${ips[0]} "$(typeset -f label_nodes); label_nodes"

# enable root ssh access
for i in ${ips[@]}
do
  ssh -i kp- -oStrictHostKeyChecking=no centos@$i "$(typeset -f allow_root_ssh); allow_root_ssh"
done

# clone gluster k8s repository
ssh -i kp- -oStrictHostKeyChecking=no centos@${ips[0]} "git clone https://github.com/gluster/gluster-kubernetes.git"