#!/bin/bash

rm .ssh/known_hosts
for i in $ips
do
  ssh ubuntu@$i -oStrictHostKeyChecking=no -i kp- "sudo apt-get update && sudo apt-get upgrade -y && sudo apt-get autoclean && sudo apt-get autoremove -y && sudo apt-get install htop -y && bash <(curl -s https://raw.githubusercontent.com/Augugrumi/vagrantfiles/master/kubernetes/ubuntu16/bootstrap.sh) && sudo reboot" & echo "Launched in $i"
done

# wait that all host are ready
for i in $ips
do
  while [[ $rc -ne 0 ]]
  do
    ssh $i
    rc=$?
  done
done

# create etc/hosts
for i in ${ips[@]}; do
  echo "$i $(nova list | grep $i | cut -d"|" -f3 | tr -d '[:space:]')" > /tmp/hosts
done

# copying hosts to all hosts
scp -i kp- -oStrictHostKeyChecking=no -P 10243 /tmp/hosts ubuntu@openstack.math.unipd.it/home/ubuntu

printf "%s" "${ips[@]}" > /tmp/ips
ssh oStrictHostKeyChecking=no -i kp- "mapfile ips < /tmp/ips; for i in `${ips[@]}`; do scp -i kp- -oStrictHostKeyChecking=no /tmp/hosts ubuntu@$i:/etc/hosts; done"

ssh -i kp- -oStrictHostKeyChecking=no -p 10243 ubuntu@openstack.math.unipd.it "ssh ubuntu@192.168.29.22 -i kp- \"bash <(curl -s https://raw.githubusercontent.com/Augugrumi/init-script/develop/kubernetes/on_master.sh)\" "

