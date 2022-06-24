cat <<EOF
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: traefik
  namespace: kube-system
spec:
  valuesContent: |-
    additionalArguments:
      - "--log.level=DEBUG"
EOF
if [ -n "${CERT_RESOLVER}" ]; then
  cat <<EOF
      - "--certificatesresolvers.le-prod.acme.email=${ACME_EMAIL}"
      - "--certificatesresolvers.le-prod.acme.storage=/data/acme-prod.json"
      - "--certificatesresolvers.le-prod.acme.tlschallenge=true"
      - "--certificatesresolvers.le-prod.acme.caServer=https://acme-v02.api.letsencrypt.org/directory"
      - "--certificatesresolvers.le-staging.acme.email=${ACME_EMAIL}"
      - "--certificatesresolvers.le-staging.acme.storage=/data/acme-staging.json"
      - "--certificatesresolvers.le-staging.acme.tlschallenge=true"
      - "--certificatesresolvers.le-staging.acme.caServer=https://acme-staging-v02.api.letsencrypt.org/directory"
EOF
fi
cat <<EOF
    # dashboard:
    #   enabled: true
    ports:
      traefik:
        expose: false
EOF
if [ ${PUBLIC_PORT} -ne 443 ]; then
  cat <<EOF
      web:
        expose: false
      websecure:
        expose: false
      jitsi-meet:
        port: ${PUBLIC_PORT}
        expose: true
        exposedPort: ${PUBLIC_PORT}
        protocol: TCP
EOF
fi
if [ -n "${EXCLUDE_JVB}" ]; then
  cat <<EOF
      xmpp-prod:
        port: 5222
        expose: true
        exposedPort: 5222
        protocol: TCP
      xmpp-test:
        port: 5223
        expose: true
        exposedPort: 5223
        protocol: TCP
EOF
fi
