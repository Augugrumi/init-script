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

function copy_file() {
  scp -i kp- -oStrictHostKeyChecking=no $3 centos@$1:$3
  ssh -i kp- -oStrictHostKeyChecking=no centos@$1 "sudo cat $3 | sudo tee -a /etc/hosts"
  scp -i kp- -oStrictHostKeyChecking=no $2 centos@$1:$2
}

function main() {

  # default values
  ips=()
  branch="master"
  port=10243
  toExit=0

  # catch arguments passed
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

      # install all stuff needed
      msg info "Launching install_kubectl_repo"
      rm .ssh/known_hosts
      ssh -i kp- -oStrictHostKeyChecking=no -p $port ubuntu@openstack.math.unipd.it "rm -f .ssh/known_hosts && bash <(curl -s https://raw.githubusercontent.com/Augugrumi/init-script/$branch/kubernetes/install_kubectl_repo.sh) $ipsfile"

      # create etc/hosts
      msg info "Generating /etc/hosts file"
      hostsfile=$(mktemp)
      for i in ${ips[@]}; do
        echo "$i $(nova list | grep $i | cut -d"|" -f3 | tr -d '[:space:]').novalocal" >> $hostsfile
      done

      # wait for all nodes are rebooted
      for i in ${ips[@]}
      do
        ssh -i kp- -oStrictHostKeyChecking=no -p $port ubuntu@openstack.math.unipd.it "$(typeset -f wait_node); wait_node $i"
      done
  
      # copy ipsfile and hosts file to every node
      msg info "Copying necessary files..."
      scp -i kp- -oStrictHostKeyChecking=no -P $port $hostsfile ubuntu@openstack.math.unipd.it:$hostsfile
      for i in ${ips[@]}
      do
        ssh -i kp- -oStrictHostKeyChecking=no -p $port ubuntu@openstack.math.unipd.it "$(typeset -f copy_file); copy_file $i $ipsfile $hostsfile"
      done
  
      # copyng the key in the master node
      msg info "Copying the keys in master..."
      ssh -i kp- -oStrictHostKeyChecking=no -p $port ubuntu@openstack.math.unipd.it "rm -f .ssh/known_hosts && scp -i kp- -oStrictHostKeyChecking=no /home/ubuntu/kp- centos@${ips[0]}:/home/centos/kp-"
      ssh -i kp- -oStrictHostKeyChecking=no -p $port ubuntu@openstack.math.unipd.it "rm -f .ssh/known_hosts && ssh centos@${ips[0]} -oStrictHostKeyChecking=no -i kp- \"bash <(curl -s https://raw.githubusercontent.com/Augugrumi/init-script/$branch/kubernetes/on_master.sh) $ipsfile\""
  fi
}

main $@
