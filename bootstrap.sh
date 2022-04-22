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

# traefik set global argument for acme challenge needs.
#  globalArguments:
#  - "--global.checknewversion"
#  - "--global.sendanonymoususage"
#  - "--providers.kubernetescrd"
#  - "--certificatesresolvers.myresolver.acme.tlschallenge"
#  - "--certificatesresolvers.myresolver.acme.email=foo@you.com"
#  - "--certificatesresolvers.myresolver.acme.storage=acme.json"
#  Please note that this is the staging Let's Encrypt server.
#  Once you get things working, you should remove that whole line altogether.
#  - "--certificatesresolvers.myresolver.acme.caserver=https://acme-staging-v02.api.letsencrypt.org/directory"

helm repo add traefik https://helm.traefik.io/traefik
sudo -E helm upgrade traefik traefik/traefik  --install -n kube-system --reuse-values -f traefik-values.yml
