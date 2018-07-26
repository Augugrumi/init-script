#!/bin/bash

function deleting_and_creating_machines() {
  msg info "Creating machines"
  nova delete k8-{1..4} &> /dev/null
  vmlaunch -i "k8-" -n "vibes_eth" -s "davmarkp0" -m "4" -r "centos_srv_1805" &> /dev/null
}

function deleting_and_creating_volumes() {
  msg info "Creating volumes"
  openstack volume delete v2 v3 v4 &> /dev/null
  openstack volume create --size 40 v2 &> /dev/null && openstack volume create --size 40 v3 &> /dev/null && openstack volume create --size 40 v4 &> /dev/null
}

source launch.sh $1

toWait=()

. <(curl -s https://raw.githubusercontent.com/Polpetta/minibashlib/master/minibashlib.sh)
mb_load "logging"

deleting_and_creating_machines &
toWait+=($!)

deleting_and_creating_volumes &
toWait+=($!)

msg info "Waiting for the creation..."

for i in ${toWait[@]}
do
    wait $i
done

openstack server add volume k8-2 v2 && openstack server add volume k8-3 v3 && openstack server add volume k8-4 v4 &> /dev/null

nova list | grep k8-
