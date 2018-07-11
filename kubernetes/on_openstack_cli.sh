#!/bin/bash

function msg () {
    # 3 type of messages:
    # - info
    # - warn
    # - err
    local color=""
    local readonly default="\033[m" #reset
    if [ "$1" = "info" ]
    then
        color="\033[0;32m" #green
    elif [ "$1" = "warn" ]
    then
        color="\033[1;33m" #yellow
    elif [ "$1" = "err" ]
    then
        color="\033[0;31m" #red
    fi

    echo -e "$color==> $2$default"
}

function validateIP() {
  if [[ $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo 0
  else
    echo 1
  fi
}

ips=()
toExit=0
branch="master"
while getopts ":a:b:" opt; do
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
            b)
                branch="$OPTARG"
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
    ssh -i kp- -oStrictHostKeyChecking=no -p 10243 ubuntu@openstack.math.unipd.it "bash <(curl -s https://raw.githubusercontent.com/Augugrumi/init-script/$branch/kubernetes/install_kubectl_repo.sh)"

    echo "" > /tmp/hosts
    # create etc/hosts
    for i in ${ips[@]}; do
      echo "$i $(nova list | grep $i | cut -d"|" -f3 | tr -d '[:space:]')" >> /tmp/hosts
    done

    # copying hosts to first ssh
    scp -i kp- -oStrictHostKeyChecking=no -P 10243 /tmp/hosts ubuntu@openstack.math.unipd.it:/tmp/hosts

    ssh -i kp- -oStrictHostKeyChecking=no -p 10243 ubuntu@openstack.math.unipd.it "scp -i kp- -oStrictHostKeyChecking=no /home/ubuntu/kp- ubuntu@${ips[0]}:/home/ubuntu/kp-"

    sleep 30

    # wait that all host are ready
    ssh -oStrictHostKeyChecking=no -i kp- -p 10243 ubuntu@openstack.math.unipd.it "bash <(curl -s https://raw.githubusercontent.com/Augugrumi/init-script/$branch/kubernetes/wait_and_copy_hosts.sh)"

    ssh -i kp- -oStrictHostKeyChecking=no -p 10243 ubuntu@openstack.math.unipd.it "ssh ubuntu@${ips[0]} -oStrictHostKeyChecking=no -i kp- \"bash <(curl -s https://raw.githubusercontent.com/Augugrumi/init-script/$branch/kubernetes/on_master.sh)\""
fi
