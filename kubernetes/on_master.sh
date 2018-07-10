#!/bin/bash

# Updating Kubernetes Configuration
tac /etc/systemd/system/kubelet.service.d/10-kubeadm.conf | awk '!p && /Environment/{print "Environment=\"cgroup-driver=systemd/cgroup-driver=cgroupfs\""; p=1} 1' | tac > /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

# todo -> ssh on master
mapfile ips < /tmp/ips
kubeadm init --apiserver-advertise-address=${ips[0]} --pod-network-cidr=192.168.0.0/16 | grep "kubeadm join" > /tmp/joincommand

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

kubectl get pods -o wide --all-namespaces

# set up calico
kubectl apply -f https://docs.projectcalico.org/v3.1/getting-started/kubernetes/installation/hosted/kubeadm/1.7/calico.yaml

# set up dashboard
kubectl create -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recommended/kubernetes-dashboard.yaml

kubectl create serviceaccount dashboard -n default
kubectl create clusterrolebinding dashboard-admin -n default \
 --clusterrole=cluster-admin \
 --serviceaccount=default:dashboard
kubectl get secret $(kubectl get serviceaccount dashboard -o jsonpath="{.secrets[0].name}") -o jsonpath="{.data.token}" | base64 --decode >  secret.txt

for i in ${ips[@]}; do ssh ubuntu@$i -oStrictHostKeyChecking=no -i kp- $(cat /tmp/joincommand) & echo "Launched in $i"; done
