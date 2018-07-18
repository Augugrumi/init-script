#!/bin/bash

. <(curl -s https://raw.githubusercontent.com/Polpetta/minibashlib/master/minibashlib.sh)

# require ips are stored in /tmp/ips file
read -a ips <<< $(cat $1)

mb_load "logging"

msg info "Ping every machine to see if it's online..."
# ping machine in order to check if they are rebooted
for i in ${ips[@]}
do
  while [[ $rc -ne 0 ]]
  do
    msg warn "Waiting for $i..."
    ping $i -c1
    rc=$?
    msg info "Exit code for ping was: $rc"
  done
  rc=1
done

msg info "Copying hosts and other ips in all machines"

msg warn "Hostfile content: $(cat $2)"
# copy hosts and other ips in all machines
for i in ${ips[@]}
do
  scp -i kp- -oStrictHostKeyChecking=no $2 centos@$i:$2
  ssh -i kp- -oStrictHostKeyChecking=no centos@$i "sudo cat $2 | sudo tee -a /etc/hosts"
  scp -i kp- -oStrictHostKeyChecking=no $1 centos@$i:$1
done
msg info "Done copying /etc/hosts"
