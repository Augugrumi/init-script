#!/bin/bash

# require ips file in /tmp/ with the array of ips of the hosts
read -a ips <<< $(cat $1)
 
toWait=()
echo ${ips[@]}
for i in ${ips[@]}
do
    # update machiens and install necessary sw
    ssh ubuntu@$i -oStrictHostKeyChecking=no -i kp- "sudo apt-get update && sudo apt-get upgrade -y && sudo apt-get autoclean && sudo apt-get autoremove -y && sudo apt-get install htop -y && bash <(curl -s https://raw.githubusercontent.com/Augugrumi/vagrantfiles/master/kubernetes/ubuntu16/bootstrap.sh) && sudo reboot" &
    # store all PID of process in order to wait until all machine are ready and rebooted
    toWait+=($!)
done
echo ${toWait[@]}

# code for waiting for the machine
for i in ${toWait[@]}
do
    wait $i
done
