#!/usr/bin/env bash

function err {
    echo -e $1 1>&2
    exit 1
}

# check usage
if [ $# -ne 2 ]; then
  err "usage: $0 <fully-qualified-host-name> <acme_email_address>"
fi

# check sudo
if [ $EUID -ne 0 ]; then
  err "sudo?"
fi

# host OS packages
apt update && apt -y install grep bind9-dnsutils iproute2 curl wget git

# parameters
export FQDN=$1
export ACME_EMAIL=$2

if [[ "${FQDN}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  export PUBLIC_IP=${FQDN}
  export FQDN=""
  if [ -z "${TLS_CERT}" ] || [ -z "${TLS_KEY}" ]; then
    err "both of 'TLS_CERT' and 'TLS_KEY' envvars should be specified when deploying without domain name"
  fi
else
  export PUBLIC_IP=$(nslookup ${FQDN} | grep -A1 Name: | grep Address: | cut -d' ' -f2 | grep -v ':' | head -1)
fi

if [ -z "${PUBLIC_IP}" ]; then
  err "can't resolve hostname: ${1}"
else
  echo "resolved hostname '${1}' to ip address ${PUBLIC_IP}"
fi

if [ ${FQDN} != "localhost" ] && ! (curl -s https://ipinfo.io/ip | grep -q ${PUBLIC_IP}); then
  err "the host doesn't have such public ip: ${PUBLIC_IP}, but these: \n$(curl -s https://ipinfo.io/ip)"
fi

if [ -n "${TEST_INSTALL}" ]; then
  export HELM_NAME=jitsitest
  export NAMESPACE=test
  export JVB_PORT=30001
else
  export HELM_NAME=jitsi
  export NAMESPACE=prod
  export JVB_PORT=30000
fi

# versions
K3S_VERSION=${K3S_VERSION:-"v1.24.1+k3s1"}
HELM_VERSION=${HELM_VERSION:-"v3.9.0"}
ARGOCD_VERSION=${ARGOCD_VERSION:-"v2.4.2"}
HELM_ARCHIVE="helm-${HELM_VERSION}-linux-amd64.tar.gz"
DEPLOY_GIT_REPO=${DEPLOY_GIT_REPO:-"https://github.com/shanghailug/jitsi-deploy.git"}

# workspace
WS_DIR=${HOME}/deploy/$(date +"%Y%m%d_%H%M%S")
if [ -n "${RUN_IN_CI}" ]; then
  SRC_DIR=${PWD}
else
  SRC_DIR=${WS_DIR}/jitsi-deploy
fi
mkdir -p ${WS_DIR}

function get_helm {
  if ! which helm || ! ( helm version | grep -q ${HELM_VERSION} ); then
    cd ${WS_DIR}/
    wget -nv https://get.helm.sh/${HELM_ARCHIVE}
    tar -zxvf ${HELM_ARCHIVE}
    mv $(find -type f -name helm) /usr/local/bin/
  fi
}

function get_src {
  if [ -z "${RUN_IN_CI}" ]; then
    cd ${WS_DIR}/
    git clone ${DEPLOY_GIT_REPO}
    cd $SRC_DIR/
    if [ -n "${DEPLOY_GIT_VERSION}" ]; then
      git checkout ${DEPLOY_GIT_VERSION}
    fi
  fi
}

function do_k3s {
  INSTALL_K3S=
  # nuke
  if [ -n "${NUKE_K3S}" ] && [ -f /usr/local/bin/k3s-uninstall.sh ]; then
    /usr/local/bin/k3s-uninstall.sh
    INSTALL_K3S=1
  elif ! which k3s; then
    INSTALL_K3S=1
  fi

  # install k3s
  if [ -n "${INSTALL_K3S}" ]; then
    curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=${K3S_VERSION} INSTALL_K3S_EXEC="--tls-san ${PUBLIC_IP}" sh -
  fi

  echo -n "waiting for k3s server node to become ready ."
  while ! (kubectl get node | grep -q -w Ready); do
    echo -n "."
    sleep 1
  done
  echo "ready."
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
  kubectl get node -o wide
}

function get_argocd {
  if ! which argocd || ! (argocd -n argocd version --client | grep ^argocd: | grep -q ${ARGOCD_VERSION}); then
    cd ${WS_DIR}/
    wget -nv https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-amd64
    chmod a+x argocd-linux-amd64
    mv argocd-linux-amd64 /usr/local/bin/argocd
  fi
}

function do_traefik {
  cd ${SRC_DIR}/
  ./traefik-config.yaml.sh | kubectl apply -f -

  echo -n "waiting for helm-install-traefik to become ready ."
  while [ $(kubectl -n kube-system get job | grep helm-install-traefik | grep -c '1/1') -ne 2 ]; do
    echo -n "."
    sleep 1
  done
  echo "ready."
  kubectl -n kube-system get job -o wide

  if [ -n "${TLS_CERT}" ] && [ -n "${TLS_KEY}" ]; then
    if kubectl -n default get secret | grep -q tls-secret; then
      kubectl -n default delete secret tls-secret
    fi
    kubectl -n default create secret tls tls-secret --cert ${TLS_CERT} --key ${TLS_KEY}
    kubectl apply -f tlsstore.yaml
  fi
}

function do_argocd {
  cd ${SRC_DIR}/

  kubectl create ns argocd --dry-run=client -o yaml | kubectl apply -f -
  kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml
  kubectl apply -f argocd/cmd-params-cm.yaml
  kubectl -n argocd rollout restart deploy/argocd-server
  argocd/ingressroute-server.yaml.sh | kubectl apply -f -
  # ARGOCD_PASSWD=$(kubectl -n argocd get secret/argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)

  echo -n "waiting for argocd to become ready ."
  while [ $(kubectl -n argocd get pods | grep -c '1/1') -ne 7 ]; do
    echo -n "."
    sleep 1
  done
  echo "ready."
  kubectl -n argocd get all
}

function do_chart {
  cd ${SRC_DIR}/jitsi

  if [ -n "${EXCLUDE_JVB}" ]; then
    EXCLUDE_JVB_VALUES_FILE="-f values-jvb-off.yaml"
  fi

  if [ -n "${STAGING_CERT}" ]; then
    CERT_RESOLVER="le-staging"
  else
    CERT_RESOLVER="le-prod"
  fi

  helm -n ${NAMESPACE} upgrade -i --create-namespace ${HELM_NAME} . \
    -f values.yaml \
    $EXCLUDE_JVB_VALUES_FILE \
    --set certResolver=${CERT_RESOLVER} \
    --set fqdn="${FQDN}" \
    --set jitsi-meet.publicURL=https://${FQDN:-${PUBLIC_IP}} \
    --set jitsi-meet.jvb.publicIP=${PUBLIC_IP} \
    --set jitsi-meet.jvb.UDPPort=${JVB_PORT}
}

function do_app {
  cd ${WS_DIR}/

  if [ -n "${DEPLOY_GIT_VERSION}" ]; then
    SET_GIT_REVISION="--revision ${DEPLOY_GIT_VERSION}"
  fi

  if [ -n "${EXCLUDE_JVB}" ]; then
    EXCLUDE_JVB_VALUES_FILE="--values values-jvb-off.yaml"
  fi

  if [ -n "${STAGING_CERT}" ]; then
    CERT_RESOLVER="le-staging"
  else
    CERT_RESOLVER="le-prod"
  fi

  argocd login --core
  ORIG_NAMESPACE=$(kubectl config view --minify -o jsonpath='{..namespace}')
  kubectl config set-context --current --namespace=argocd

  kubectl create ns ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
  argocd app create ${HELM_NAME} \
    --upsert \
    --repo ${DEPLOY_GIT_REPO} \
    --path jitsi \
    ${SET_GIT_REVISION} \
    --dest-server https://kubernetes.default.svc \
    --dest-namespace ${NAMESPACE} \
    --values values.yaml \
    ${EXCLUDE_JVB_VALUES_FILE} \
    --helm-set certResolver=${CERT_RESOLVER} \
    --helm-set fqdn="${FQDN}" \
    --helm-set jitsi-meet.publicURL=https://${FQDN:-${PUBLIC_IP}} \
    --helm-set jitsi-meet.jvb.publicIP=${PUBLIC_IP} \
    --helm-set jitsi-meet.jvb.UDPPort=${JVB_PORT}

  sleep 5 # there is a race if sync happens too quickly, so that it becomes a partial sync
  argocd app sync ${HELM_NAME}
  kubectl config set-context --current --namespace=${ORIG_NAMESPACE}
}

# installation starts from here
(
  get_helm

  get_src

  do_k3s

  get_argocd # 'argocd version' depends on k3s setup

  do_traefik

  do_argocd

  do_app

# installation ends here
) 2>&1 | tee ${WS_DIR}/deploy.log
