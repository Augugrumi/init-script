#!/bin/bash

. <(curl -s https://raw.githubusercontent.com/Polpetta/minibashlib/master/minibashlib.sh)

function validateIP() {
  if [[ $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo 0
  else
    echo 1
  fi
}

mb_load "logging"
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
    ipsfile=$(mktemp)
    echo "${ips[@]}" > $ipsfile
    scp -i kp- -oStrictHostKeyChecking=no -P $port $ipsfile ubuntu@openstack.math.unipd.it:$ipsfile

    echo ${ips[@]}
    rm .ssh/known_hosts
    msg info "Launching install_kubectl_repo"
    ssh -i kp- -oStrictHostKeyChecking=no -p $port ubuntu@openstack.math.unipd.it "rm -f .ssh/known_hosts && bash -x <(curl -s https://raw.githubusercontent.com/Augugrumi/init-script/$branch/kubernetes/install_kubectl_repo.sh) $ipsfile"

    hostsfile=$(mktemp)
    # create etc/hosts
    for i in ${ips[@]}; do
      echo "$i $(nova list | grep $i | cut -d"|" -f3 | tr -d '[:space:]')" >> $hostsfile
    done

    msg info "Copying the keys in every machine..."
    # copying hosts to first ssh
    scp -i kp- -oStrictHostKeyChecking=no -P $port $hostsfile ubuntu@openstack.math.unipd.it:$hostsfile

    ssh -i kp- -oStrictHostKeyChecking=no -p $port ubuntu@openstack.math.unipd.it "rm -f .ssh/known_hosts && scp -i kp- -oStrictHostKeyChecking=no /home/ubuntu/kp- centos@${ips[0]}:/home/centos/kp-"
    msg info "Done copying the keys"

    msg warn "Sleeping 30 sec..."
    sleep 30

    msg info "Waiting that all the nodes are up..."
    # wait that all host are ready
    ssh -oStrictHostKeyChecking=no -i kp- -p $port ubuntu@openstack.math.unipd.it "rm -f .ssh/known_hosts && bash -x <(curl -s https://raw.githubusercontent.com/Augugrumi/init-script/$branch/kubernetes/wait_and_copy_hosts.sh) $ipsfile $hostsfile"

    msg info "Finalizing the cluster in the master..."
    ssh -i kp- -oStrictHostKeyChecking=no -p $port ubuntu@openstack.math.unipd.it "rm -f .ssh/known_hosts && ssh centos@${ips[0]} -oStrictHostKeyChecking=no -i kp- \"bash -x <(curl -s https://raw.githubusercontent.com/Augugrumi/init-script/$branch/kubernetes/on_master.sh) $ipsfile\""
fi
