#!/bin/bash

branch="master"
while getopts ":b:" opt; do
        case $opt in
            b)
                branch="$OPTARG"
                ;;
        esac
done

bash <(curl -s https://raw.githubusercontent.com/Augugrumi/init-script/$branch/kubernetes/on_openstack_cli.sh) $@