#!/bin/bash

# require ips file in /tmp/ with the array of ips of the hosts
read -a ips <<< $(cat $1)
 
toWait=()
echo ${ips[@]}
for i in ${ips[@]}
do
    # update machiens and install necessary sw
    ssh centos@$i -oStrictHostKeyChecking=no -i kp- "bash -x <(curl -s https://raw.githubusercontent.com/Augugrumi/vagrantfiles/42085960cd671e3f226534ac272bbe9a30b2240f/kubernetes/centos/bootstrap.sh) && sudo reboot" &
    # store all PID of process in order to wait until all machine are ready and rebooted
    toWait+=($!)
done
echo ${toWait[@]}

# code for waiting for the machine
for i in ${toWait[@]}
do
    wait $i
done
