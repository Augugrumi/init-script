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
port=10243
while getopts ":a:b:p:" opt; do
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
            p)
                port="$OPTARG"
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
    ipsfile=$(mktemp)
    echo "${ips[@]}" > $ipsfile
    scp -i kp- -oStrictHostKeyChecking=no -P $port $ipsfile ubuntu@openstack.math.unipd.it:$ipsfile

    echo ${ips[@]}
    rm .ssh/known_hosts
    ssh -i kp- -oStrictHostKeyChecking=no -p $port ubuntu@openstack.math.unipd.it "rm -f .ssh/known_hosts && bash <(curl -s https://raw.githubusercontent.com/Augugrumi/init-script/$branch/kubernetes/install_kubectl_repo.sh) $ipsfile"

    hostsfile=$(mktemp)
    # create etc/hosts
    for i in ${ips[@]}; do
      echo "$i $(nova list | grep $i | cut -d"|" -f3 | tr -d '[:space:]')" >> $hostsfile
    done

    # copying hosts to first ssh
    scp -i kp- -oStrictHostKeyChecking=no -P $port $hostsfile ubuntu@openstack.math.unipd.it:$hostsfile

    ssh -i kp- -oStrictHostKeyChecking=no -p $port ubuntu@openstack.math.unipd.it "rm -f .ssh/known_hosts && scp -i kp- -oStrictHostKeyChecking=no /home/ubuntu/kp- ubuntu@${ips[0]}:/home/ubuntu/kp-"

    sleep 30

    # wait that all host are ready
    ssh -oStrictHostKeyChecking=no -i kp- -p $port ubuntu@openstack.math.unipd.it "rm -f .ssh/known_hosts && bash <(curl -s https://raw.githubusercontent.com/Augugrumi/init-script/$branch/kubernetes/wait_and_copy_hosts.sh) $ipsfile $hostsfile"

    ssh -i kp- -oStrictHostKeyChecking=no -p $port ubuntu@openstack.math.unipd.it "rm -f .ssh/known_hosts && ssh ubuntu@${ips[0]} -oStrictHostKeyChecking=no -i kp- \"bash -x <(curl -s https://raw.githubusercontent.com/Augugrumi/init-script/$branch/kubernetes/on_master.sh) $ipsfile\""
fi
