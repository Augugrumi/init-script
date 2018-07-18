#!/bin/bash

. <(curl -s https://raw.githubusercontent.com/Polpetta/minibashlib/master/minibashlib.sh)

# require ips file in /tmp/ with the array of ips of the hosts
read -a ips <<< $(cat $1)

mb_load "logging"
toWait=()
echo ${ips[@]}
msg info "Preparing to bootstrap..."
for i in ${ips[@]}
do
    # update machiens and install necessary sw
    ssh centos@$i -oStrictHostKeyChecking=no -i kp- "bash -x <(curl -s https://raw.githubusercontent.com/Augugrumi/vagrantfiles/oldversion/kubernetes/centos/bootstrap.sh) && sudo reboot" &
    # store all PID of process in order to wait until all machine are ready and rebooted
    toWait+=($!)
done

msg info "Done bootstrapping"
echo ${toWait[@]}

# code for waiting for the machine
for i in ${toWait[@]}
do
    wait $i
done

msg info "All nodes have finished their job, exiting install_kubectl_repo.sh"
