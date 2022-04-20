#!/bin/bash

# k3s and set current context as k3s , k3s use trafik as ingress controller by default.
(which k3s &> /dev/null && test -f /etc/rancher/k3s/k3s.yaml)  || \
    curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644 --disable traefik

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl get namespace jitsi &> /dev/null || \
    sudo -E kubectl create namespace jitsi

sudo -E kubectl config set-context  --current --namespace=jitsi

# helm
which helm &> /dev/null || \
    curl -sfL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3  | bash -s -

# jitsi
sudo -E helm repo add jitsi https://jitsi-contrib.github.io/jitsi-helm/
sudo -E helm install shlug-jitsi jitsi/jitsi-meet -f values.yml -n jitsi

