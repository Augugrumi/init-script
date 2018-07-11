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

function exesudo ()
{
    ### ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
    #
    # LOCAL VARIABLES:
    #
    ### ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

    #
    # I use underscores to remember it's been passed
    local _funcname_="$1"

    local params=( "$@" )               ## array containing all params passed here
    local tmpfile="/dev/shm/$RANDOM"    ## temporary file
    local filecontent                   ## content of the temporary file
    local regex                         ## regular expression
    local func                          ## function source


    ### ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
    #
    # MAIN CODE:
    #
    ### ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##

    #
    # WORKING ON PARAMS:
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    #
    # Shift the first param (which is the name of the function)
    unset params[0]              ## remove first element
    # params=( "${params[@]}" )     ## repack array


    #
    # WORKING ON THE TEMPORARY FILE:
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    content="#!/bin/bash\n\n"

    #
    # Write the params array
    content="${content}params=(\n"

    regex="\s+"
    for param in "${params[@]}"
    do
        if [[ "$param" =~ $regex ]]
            then
                content="${content}\t\"${param}\"\n"
            else
                content="${content}\t${param}\n"
        fi
    done

    content="$content)\n"
    echo -e "$content" > "$tmpfile"

    #
    # Append the function source
    echo "#$( type "$_funcname_" )" >> "$tmpfile"

    #
    # Append the call to the function
    echo -e "\n$_funcname_ \"\${params[@]}\"\n" >> "$tmpfile"


    #
    # DONE: EXECUTE THE TEMPORARY FILE WITH SUDO
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    sudo bash "$tmpfile"
    rm "$tmpfile"
}

# function to add Environment="cgroup-driver=systemd/cgroup-driver=cgroupfs" to k8s configuration file
function addLine() {
  sudo chmod 666 $1 
  tac $1 | awk '!p && /Environment/{print "Environment=\"cgroup-driver=systemd/cgroup-driver=cgroupfs\""; p=1} 1' | tac > $1.temp
  cat $1.temp > $1
  rm $1.temp
  sudo chmod 640 $1
}

# function that waits until all pods are ready
function wait_ready() {
  finished=1
  while [ "$finished" -ne 0 ]; do
    finished=0
    for i in $(cat $1 | tail -n +2 | awk '{ print $1 $3 }' | tr -d "kube-system-" | cut -d"/" -f1)
    do
      if [ "$i" -eq 0 ]; then
        finished=1
        sleep 5
        break
      fi
    done
  done
}

# Updating Kubernetes Configuratio -> exesudo to run function with sudoers privileges
exesudo 'addLine' /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

# require ips file in /tmp/ with the array of ips of the hosts
read -a ips <<< $(cat /tmp/ips)
# init kubeadm and save join string taking first ip as master
sudo kubeadm init --apiserver-advertise-address=${ips[0]} --pod-network-cidr=192.168.0.0/16 | grep "kubeadm join" > /home/ubuntu/joincommand

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

kubectl get pods --all-namespaces | wait_ready

# set up calico
kubectl apply -f https://docs.projectcalico.org/v3.1/getting-started/kubernetes/installation/hosted/kubeadm/1.7/calico.yaml

# waits for pods
kubectl get pods --all-namespaces | wait_ready

# set up dashboard
kubectl create -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recommended/kubernetes-dashboard.yaml

# waits for pods
kubectl get pods --all-namespaces | wait_ready

# setup kubectl
kubectl create serviceaccount dashboard -n default
kubectl create clusterrolebinding dashboard-admin -n default \
 --clusterrole=cluster-admin \
 --serviceaccount=default:dashboard
kubectl get secret $(kubectl get serviceaccount dashboard -o jsonpath="{.secrets[0].name}") -o jsonpath="{.data.token}" | base64 --decode >  secret.txt

# run 'kubectl proxy' on screen -> access via 'screen -r kubectl_proxy_screen'
screen -dmS kubectl_proxy_screen bash
screen -S kubectl_proxy_screen -X stuff "kubectl proxy
"

# run join command on all 
for i in ${ips[@]}
do
  ssh ubuntu@$i -oStrictHostKeyChecking=no -i kp- "$(cat /home/ubuntu/joincommand)" &
done

# print the secret token to access kubernetes dashboard
msg info "******************* YOUR SECRET TOKEN *******************"
cat secret.txt
echo "\n"
msg info "*********************************************************"
