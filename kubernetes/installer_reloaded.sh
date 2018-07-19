#!/bin/bash

. <(curl -s https://raw.githubusercontent.com/Polpetta/minibashlib/master/minibashlib.sh)

function help () {
    echo "Usage: $0 -p [PORT] -a [ADDRESSES] -o [OPENSTACK_RC_FILE] -n [MACHINE-NAME]"
}

function main () {

    mb_load
    local ips=()
    local port
    local openstack_file_path
    local machine_name

    while getopts ":b: :a: :p: :h" opt; do
        case $opt in
            b)
                branch="$OPTARG"
                ;;
            a)
                ips+=("$OPTARG")
                ;;
            p)
                port="$OPTARG"
            h)
                help
                exit 0
                ;;
            o)
                openstack_file_path="$OPTARG"
                ;;
            m)
                machine_name="$OPTARG"
                if [ -z "$openstack_file_path" ]
                then
                    msg warn "Openstack rc file not specified"
                fi
                ;;
            \?)
                msg err "Invalid option: -$OPTARG" >&2
                exit 1
                ;;
            :)
                msg err "Option -$OPTARG requires an argument." >&2
                exit 1
                ;;
        esac
    done

    
}

main $@
