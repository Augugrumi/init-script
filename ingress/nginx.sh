#!/bin/bash

git clone https://github.com/nginxinc/kubernetes-ingress.git --depth 1
helm install --name nginxcontroller . --set controller.replicaCount=2,controller.service.type=NodePort,controller.service.externalTrafficPolicy=Cluster

echo "To install your services run
helm install <service-release> --name <your-service-name> --set serviceType=NodePort,nodePorts.http=<your-port>"
