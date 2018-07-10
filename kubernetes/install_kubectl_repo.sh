#!/bin/bash

# require ips file in /tmp/ with the array of ips of the hosts
mapfile ips < /tmp/ips
toWait=()
echo ${ips[@]}
for i in ${ips[@]}
do
    ssh ubuntu@$i -oStrictHostKeyChecking=no -i kp- "sudo apt-get update && sudo apt-get upgrade -y && sudo apt-get autoclean && sudo apt-get autoremove -y && sudo apt-get install htop -y && bash <(curl -s https://raw.githubusercontent.com/Augugrumi/vagrantfiles/master/kubernetes/ubuntu16/bootstrap.sh) && sudo reboot" &
    toWait+=($!)
done
echo ${toWait[@]}

for i in ${toWait[@]}
do
    wait $i
done
