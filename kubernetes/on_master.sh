#!/bin/bash

. <(curl -s https://raw.githubusercontent.com/Polpetta/minibashlib/master/minibashlib.sh)

mb_load "logging"


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


function main() {
  # install screen for dashboard
  sudo yum install -y screen

  # require ips file in /tmp/ with the array of ips of the hosts
  read -a ips <<< $(cat $1)

  # init kubeadm and save join string taking first ip as master
  sudo kubeadm init --apiserver-advertise-address=${ips[0]} --pod-network-cidr=10.244.0.0/16 --ignore-preflight-errors cri | grep "kubeadm join" > /home/centos/joincommand

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

  # wait for pods
  kubectl get pods --all-namespaces | wait_ready

  # set up flannel
  kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
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

  sed -i '$ s/$/ --ignore-preflight-errors cri/' joincommand
  for i in ${ips[@]}
  do
    scp -i kp- -oStrictHostKeyChecking=no /home/centos/joincommand centos@$i:/home/centos/joincommand
    ssh centos@$i -oStrictHostKeyChecking=no -i kp- "sudo bash joincommand" &
  done

  cat <<EOF | tee /tmp/traefik-rbac.yaml
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: traefik-ingress-controller
rules:
  - apiGroups:
      - ""
    resources:
      - services
      - endpoints
      - secrets
    verbs:
      - get
      - list
      - watch
  - apiGroups:
      - extensions
    resources:
      - ingresses
    verbs:
      - get
      - list
      - watch
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: traefik-ingress-controller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: traefik-ingress-controller
subjects:
- kind: ServiceAccount
  name: traefik-ingress-controller
  namespace: kube-system
EOF

  kubectl create -f /tmp/traefik-rbac.yaml

  cat <<EOF | tee /tmp/traefik-deployment.yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: traefik-ingress-controller
  namespace: kube-system
---
kind: Deployment
apiVersion: extensions/v1beta1
metadata:
  name: traefik-ingress-controller
  namespace: kube-system
  labels:
    k8s-app: traefik-ingress-lb
spec:
  replicas: 1
  selector:
    matchLabels:
      k8s-app: traefik-ingress-lb
  template:
    metadata:
      labels:
        k8s-app: traefik-ingress-lb
        name: traefik-ingress-lb
    spec:
      serviceAccountName: traefik-ingress-controller
      terminationGracePeriodSeconds: 60
      containers:
      - image: traefik
        name: traefik-ingress-lb
        ports:
        - name: http
          containerPort: 80
        - name: admin
          containerPort: 8080
        args:
        - --api
        - --kubernetes
        - --logLevel=INFO
---
kind: Service
apiVersion: v1
metadata:
  name: traefik-ingress-service
  namespace: kube-system
spec:
  selector:
    k8s-app: traefik-ingress-lb
  ports:
    - protocol: TCP
      port: 80
      name: web
    - protocol: TCP
      port: 8080
      name: admin
  type: NodePort
EOF

  kubectl create -f /tmp/traefik-deployment.yaml

  # print the secret token to access kubernetes dashboard
  msg info "******************* YOUR SECRET TOKEN *******************"
  cat secret.txt && echo ""
  msg info "*********************************************************"
}

main $@
