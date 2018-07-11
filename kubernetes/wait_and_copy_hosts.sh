#!/bin/bash

# require ips are stored in /tmp/ips file
read -a ips <<< $(cat /tmp/ips )

# ping machine in order to check if they are rebooted
for i in ${ips[@]}
do
  while [[ $rc -ne 0 ]]
  do
    ping $i -c1
    rc=$?
  done
  rc=1
done

# copy hosts and other ips in all machines
for i in ${ips[@]}
do
  scp -i kp- -oStrictHostKeyChecking=no /tmp/hosts ubuntu@$i:/home/ubuntu/hosts
  ssh -i kp- -oStrictHostKeyChecking=no ubuntu@$i "sudo cp /home/ubuntu/hosts /etc/hosts"

  scp -i kp- -oStrictHostKeyChecking=no /tmp/ips ubuntu@$i:/tmp/ips
done
