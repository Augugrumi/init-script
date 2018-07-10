#!/bin/bash

#assume ips are stored in /tmp/ips file
read -a ips <<< $(cat /tmp/ips )
echo $(pwd)
for i in ${ips[@]}
do
  while [[ $rc -ne 0 ]]
  do
    ping $i -c1
    rc=$?
  done
  rc=1
done

for i in ${ips[@]}
do
  scp -i kp- -oStrictHostKeyChecking=no /tmp/hosts ubuntu@$i:/home/ubuntu/hosts
  scp -i kp- -oStrictHostKeyChecking=no /tmp/ips ubuntu@$i:/tmp/ips
  ssh -i kp- -oStrictHostKeyChecking=no ubuntu@$i "sudo cp /home/ubuntu/hosts /etc/hosts"
done
