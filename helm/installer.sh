#!/bin/bash

curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get | bash
echo -e "apiVersion: v1\nkind: ServiceAccount\nmetadata:\n  name: helm\n  namespace: kube-system\n---\napiVersion: rbac.authorization.k8s.io/v1beta1\nkind: ClusterRoleBinding\nmetadata:\n  name: helm\nroleRef:\n  apiGroup: rbac.authorization.k8s.io\n  kind: ClusterRole\n  name: cluster-admin\nsubjects:\n  - kind: ServiceAccount\n    name: helm\n    namespace: kube-system" > helm.yaml
kubectl create -f helm.yaml
helm init --service-account helm