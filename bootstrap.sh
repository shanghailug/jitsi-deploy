#!/bin/bash

# basic tools(git, curl)
# k3s and set current context as k3s
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644 && export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# helm
curl -sfL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3  | bash -s -
#export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
sudo helm repo add jitsi https://jitsi-contrib.github.io/jitsi-helm/
sudo helm install shlug-jitsi jitsi/jitsi-meet -f values.yml
