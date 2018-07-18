#!/bin/bash

. <(curl -s https://raw.githubusercontent.com/Polpetta/minibashlib/master/minibashlib.sh)

mb_load "logging"

function validateIP() {
  if [[ $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo 0
  else
    echo 1
  fi
}

function wait_node() {
  rc=1
  while [[ $rc -ne 0 ]]
    do
      ping $1 -c1
      rc=$?
    done
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

msg warn $branch
msg warn $port

if [ "$toExit" -ne 0 ]; then
    echo "Shit's on fire bro"
  else
    # copying all the ips to the ubuntu firts ssh
    msg warn "1"
    ipsfile=$(mktemp)
    echo "${ips[@]}" > $ipsfile
    scp -i kp- -oStrictHostKeyChecking=no -P $port $ipsfile ubuntu@openstack.math.unipd.it:$ipsfile

    msg warn "2"
    echo ${ips[@]}
    rm .ssh/known_hosts
    ssh -i kp- -oStrictHostKeyChecking=no -p $port ubuntu@openstack.math.unipd.it "rm -f .ssh/known_hosts && bash -x <(curl -s https://raw.githubusercontent.com/Augugrumi/init-script/$branch/kubernetes/install_kubectl_repo.sh) $ipsfile"

    for i in ${ips[@]}
    do
      ssh -i kp- -oStrictHostKeyChecking=no -p $port ubuntu@openstack.math.unipd.it "$(typeset -f wait_node); wait_node $i"
    done

    msg warn "3"
    hostsfile=$(mktemp)
    # create etc/hosts
    for i in ${ips[@]}; do
      echo "$i $(nova list | grep $i | cut -d"|" -f3 | tr -d '[:space:]')" >> $hostsfile
    done

    msg warn "4"
    # copying hosts to first ssh
    scp -i kp- -oStrictHostKeyChecking=no -P $port $hostsfile ubuntu@openstack.math.unipd.it:$hostsfile

    msg warn "5"
    ssh -i kp- -oStrictHostKeyChecking=no -p $port ubuntu@openstack.math.unipd.it "rm -f .ssh/known_hosts && scp -i kp- -oStrictHostKeyChecking=no /home/ubuntu/kp- centos@${ips[0]}:/home/centos/kp-"

    msg warn "6"
    # wait that all host are ready
    ssh -oStrictHostKeyChecking=no -i kp- -p $port ubuntu@openstack.math.unipd.it "rm -f .ssh/known_hosts && bash -x <(curl -s https://raw.githubusercontent.com/Augugrumi/init-script/$branch/kubernetes/wait_and_copy_hosts.sh) $ipsfile $hostsfile"

    msg warn "7"
    ssh -i kp- -oStrictHostKeyChecking=no -p $port ubuntu@openstack.math.unipd.it "rm -f .ssh/known_hosts && ssh centos@${ips[0]} -oStrictHostKeyChecking=no -i kp- \"bash -x <(curl -s https://raw.githubusercontent.com/Augugrumi/init-script/$branch/kubernetes/on_master.sh) $ipsfile\""
fi
