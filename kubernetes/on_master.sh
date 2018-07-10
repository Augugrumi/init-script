#!/bin/bash

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

function addLine() {
  sudo chmod 666 $1 
  tac $1 | awk '!p && /Environment/{print "Environment=\"cgroup-driver=systemd/cgroup-driver=cgroupfs\""; p=1} 1' | tac > $1.temp
  cat $1.temp > $1
  rm $1.temp
  sudo chmod 640 $1
}

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

# Updating Kubernetes Configuration

exesudo 'addLine' /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

# todo -> ssh on master
read -a ips <<< $(cat /tmp/ips)
sudo kubeadm init --apiserver-advertise-address=${ips[0]} --pod-network-cidr=192.168.0.0/16 | grep "kubeadm join" > /home/ubuntu/joincommand

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

kubectl get pods --all-namespaces | wait_ready

# set up calico
kubectl apply -f https://docs.projectcalico.org/v3.1/getting-started/kubernetes/installation/hosted/kubeadm/1.7/calico.yaml

kubectl get pods --all-namespaces | wait_ready

# set up dashboard
kubectl create -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recommended/kubernetes-dashboard.yaml

kubectl get pods --all-namespaces | wait_ready

kubectl create serviceaccount dashboard -n default
kubectl create clusterrolebinding dashboard-admin -n default \
 --clusterrole=cluster-admin \
 --serviceaccount=default:dashboard
kubectl get secret $(kubectl get serviceaccount dashboard -o jsonpath="{.secrets[0].name}") -o jsonpath="{.data.token}" | base64 --decode >  secret.txt

for i in ${ips[@]}
do
  ssh ubuntu@$i -oStrictHostKeyChecking=no -i kp- "$(cat /home/ubuntu/joincommand)" &
done
