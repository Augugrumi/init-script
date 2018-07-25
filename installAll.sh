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

ips=()
port=10243
branch="centos"
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

bash <(curl -s https://raw.githubusercontent.com/Augugrumi/init-script/$branch/kubernetes/on_openstack_cli.sh) $@

ssh -i kp- -oStrictHostKeyChecking=no -p $port ubuntu@openstack.math.unipd.it "bash <(curl -s https://raw.githubusercontent.com/Augugrumi/init-script/$branch/glusterfs/installer.sh) $@" 

ssh -i kp- -oStrictHostKeyChecking=no -p $port ubuntu@openstack.math.unipd.it "rm -f .ssh/known_hosts && ssh centos@${ips[0]} -oStrictHostKeyChecking=no -i kp- \"bash <(curl -s https://raw.githubusercontent.com/Augugrumi/init-script/$branch/helm/installer.sh)\""

msg info "***************SECRET TOKEN***************"
ssh -i kp- -oStrictHostKeyChecking=no -p $port ubuntu@openstack.math.unipd.it "rm -f .ssh/known_hosts && ssh centos@${ips[0]} -oStrictHostKeyChecking=no -i kp- \"cat secret.txt && echo \""
msg info "******************************************"
