#!/bin/bash

# basic tools(git, curl)

# k3s
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644
kubectl create namespace jitsi

# helm
curl -sfL get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3  | bash -s -
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
helm repo add jitsi https://jitsi-contrib.github.io/jitsi-helm/
helm install shlug-jitsi jitsi/jitsi-meet

