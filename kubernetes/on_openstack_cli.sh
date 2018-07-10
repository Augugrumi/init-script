#!/bin/bash

set -x
ips=(192.168.24 192.168.29.22 192.168.29.29 192.168.29.23)

# copying all the ips to the ubuntu firts ssh
echo "${ips[@]}" > /tmp/ips
scp -i kp- -oStrictHostKeyChecking=no -P 10243 /tmp/ips ubuntu@openstack.math.unipd.it:/tmp/ips

echo ${ips[@]}
rm .ssh/known_hosts
ssh -i kp- -oStrictHostKeyChecking=no -p 10243 ubuntu@openstack.math.unipd.it "bash -x <(curl -s https://raw.githubusercontent.com/Augugrumi/init-script/e09256e9939cedfe7b3f17377b747f325886451c/kubernetes/install_kubectl_repo.sh)"

# create etc/hosts
for i in ${ips[@]}; do
  echo "$i $(nova list | grep $i | cut -d"|" -f3 | tr -d '[:space:]')" > /tmp/hosts
done

# copying hosts to first ssh
scp -i kp- -oStrictHostKeyChecking=no -P 10243 /tmp/hosts ubuntu@openstack.math.unipd.it:/home/ubuntu

# wait that all host are ready
ssh -oStrictHostKeyChecking=no -i kp- -p 10243 ubuntu@openstack.math.unipd.it "mapfile ips < /tmp/ips; echo $(pwd); rc=1; for i in ${ips[@]}; do while [[ $rc -ne 0 ]]; do ping $i -c1; rc=$?; done; rc=1; done; for i in `${ips[@]}`; do scp -i kp- -oStrictHostKeyChecking=no /tmp/hosts ubuntu@$i:/etc/hosts; done" 

ssh -i kp- -oStrictHostKeyChecking=no -p 10243 ubuntu@openstack.math.unipd.it "ssh ubuntu@192.168.29.22 -oStrictHostKeyChecking=no -i kp- \"bash <(wget -qO- https://www.dropbox.com/s/qjvint34vythj7x/p.sh?dl=1)\" "
