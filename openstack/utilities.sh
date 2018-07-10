#!/bin/sh

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

function vmlaunch() {
  toExit=0
  while getopts ":i: :n: :r: :s: :m:" opt; do
        case $opt in
            i)
		instanceName="$OPTARG"
                ;;
            n)
                networkName="$OPTARG"
                ;;
	    r)
		imageName="$OPTARG"
		;;
            s)
                keyName="$OPTARG"
                ;;
            m)
                instanceNumber="$OPTARG"
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

  for i in $(seq 1 $instanceNumber)
  do
    if [ "$toExit" -eq 0 ]
    then
      nova boot \
      --flavor server-medium \
      --security-groups default \
      --nic net-id=$(openstack network list | grep $networkName | cut -d"|" -f2 | tr -d '[:space:]') \
      --key-name $keyName \
      --block-device source=image,id=$(openstack image list | grep $imageName | cut -d"|" -f2 | tr -d '[:space:]'),dest=volume,size=40,shutdown=remove,bootindex=0 \
      $instanceName$i || toExit=1
      sleep 30
    fi
  done
  
  for i in $(openstack port list | tail -n+4 | head -n-1 | cut -d"|" -f2 | tr -d ' ')
  do
    openstack port set --no-security-group --disable-port-security $i || echo "Error on $i"
    sleep 5
  done
  
  if [ "$toExit" -ne 0 ]
  then
    echo "Shit's on fire bro"
  fi
}


if [ -z "$1" ]
then
  echo "Need a path to your rc file"
  unset launch
else
  . $1
  export PS1='\u@\h:\w <$OS_USERNAME-$OS_PROJECT_NAME> # '
  echo "Done loading additional utilities. Use 'vmlaunch' to launch new instances."
fi
