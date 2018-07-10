#!/bin/bash

#assume ips are stored in /tmp/ips file
mapfile ips < /tmp/ips
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
  scp -i kp- -oStrictHostKeyChecking=no /tmp/hosts ubuntu@$i:/etc/hosts
done
