#!/bin/bash

# require ips are stored in /tmp/ips file
read -a ips <<< $(cat $1)

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
  scp -i kp- -oStrictHostKeyChecking=no $2 ubuntu@$i:$2
  ssh -i kp- -oStrictHostKeyChecking=no ubuntu@$i "sudo cp $2 /etc/hosts"

  scp -i kp- -oStrictHostKeyChecking=no $1 ubuntu@$i:$1
done
