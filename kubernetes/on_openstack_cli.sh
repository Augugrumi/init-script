#!/bin/bash

function validateIP() {
  if [[ $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo 0
  else
    echo 1
  fi
}

ips=()
while getopts ":a:" opt; do
        case $opt in
            a)
		valid=$(validateIP $OPTARG)
                if [ "$valid" -eq 0 ]; then
                  ips+=("$OPTARG")
                else
                  msg err "Invalid IP address: -$OPTARG" >&2
                  toExit=1
                fi
                ;;
            \?)
                msg err "Invalid option: -$OPTARG" >&2
                toExit=1
                ;;
            :)
                msg err "Option -$OPTARG requires an argument." >&2
                toExit=1
                ;;
        esac
done

if [ "$toExit" -ne 0 ]; then
    echo "Shit's on fire bro"
  else
    # copying all the ips to the ubuntu firts ssh
    echo "${ips[@]}" > /tmp/ips
    scp -i kp- -oStrictHostKeyChecking=no -P 10243 /tmp/ips ubuntu@openstack.math.unipd.it:/tmp/ips

    echo ${ips[@]}
    rm .ssh/known_hosts
    ssh -i kp- -oStrictHostKeyChecking=no -p 10243 ubuntu@openstack.math.unipd.it "bash -x <(curl -s https://raw.githubusercontent.com/Augugrumi/init-script/5ac0bc9aa79f9d8f10f1af3a7529af62f0d362d7/kubernetes/install_kubectl_repo.sh)"

    echo "" > /tmp/hosts
    # create etc/hosts
    for i in ${ips[@]}; do
      echo "$i $(nova list | grep $i | cut -d"|" -f3 | tr -d '[:space:]')" >> /tmp/hosts
    done

    # copying hosts to first ssh
    scp -i kp- -oStrictHostKeyChecking=no -P 10243 /tmp/hosts ubuntu@openstack.math.unipd.it:/tmp/hosts

    sleep 30

    # wait that all host are ready
    ssh -oStrictHostKeyChecking=no -i kp- -p 10243 ubuntu@openstack.math.unipd.it "bash -x <(curl -s https://raw.githubusercontent.com/Augugrumi/init-script/5ac0bc9aa79f9d8f10f1af3a7529af62f0d362d7/kubernetes/wait_and_copy_hosts.sh)"

    ssh -i kp- -oStrictHostKeyChecking=no -p 10243 ubuntu@openstack.math.unipd.it "ssh ubuntu@${ips[0]} -oStrictHostKeyChecking=no -i kp- \"bash -x <(curl -s https://raw.githubusercontent.com/Augugrumi/init-script/52f8ef8f61e9f37069ab2d90a9619bb81622c1f6/kubernetes/on_master.sh)\""
fi
