#!/bin/bash

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

toWait=()
echo ${ips[@]}
for i in ${ips[@]}
do
    # update machiens and install necessary sw
    ssh ubuntu@$i -oStrictHostKeyChecking=no -i kp- "sudo apt-get update && sudo apt-get upgrade -y && sudo apt-get autoclean && sudo apt-get autoremove -y && sudo apt-get install htop -y && bash <(curl -s https://raw.githubusercontent.com/Augugrumi/vagrantfiles/master/kubernetes/ubuntu16/bootstrap.sh) && sudo reboot" &
    # store all PID of process in order to wait until all machine are ready and rebooted
    toWait+=($!)
done
echo ${toWait[@]}

# code for waiting for the machine
for i in ${toWait[@]}
do
    wait $i
done

for i in ${ips[@]}
do
  scp -i kp- -oStrictHostKeyChecking=no /home/ubuntu/joincommand ubuntu@$i:/home/ubuntu/joincommand
  ssh ubuntu@$i -oStrictHostKeyChecking=no -i kp- "sudo bash joincommand" &
done