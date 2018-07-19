#!/bin/bash

. <(curl -s https://raw.githubusercontent.com/Polpetta/minibashlib/master/minibashlib.sh)

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

# function that waits until all nodes are ready
function wait_nodes_ready() {
  finished=1
  while [ "$finished" -ne 0 ]; do
    finished=0
    for i in $(kubectl get nodes | tail -n +2 | awk -F"   " '{$0=$2}1' | tr -d ' ')
    do
      if [ "$i" = "NotReady" ]; then
        finished=1
        sleep 2
        break
      fi
    done
  done
}

mb_load

# Updating Kubernetes Configuratio -> exec_root_func to run function with sudoers privileges
#exec_root_func 'addLine' /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

# require ips file in /tmp/ with the array of ips of the hosts
read -a ips <<< $(cat $1)
# init kubeadm and save join string taking first ip as master
sudo kubeadm init --apiserver-advertise-address=${ips[0]} --pod-network-cidr=192.168.0.0/16 --ignore-preflight-errors cri | grep "kubeadm join" > /home/centos/joincommand

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

kubectl get pods --all-namespaces | wait_ready

# set up flannel
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

# waits for pods
kubectl get pods --all-namespaces | wait_ready

kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/k8s-manifests/kube-flannel-rbac.yml

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

wait_nodes_ready

for i in ${ips[@]}
do
  scp -i kp- -oStrictHostKeyChecking=no /home/centos/joincommand centos@$i:/home/centos/joincommand
  ssh centos@$i -oStrictHostKeyChecking=no -i kp- "sudo bash -x joincommand" &
done

# print the secret token to access kubernetes dashboard
msg info "******************* YOUR SECRET TOKEN *******************"
cat secret.txt && echo ""
msg info "*********************************************************"
