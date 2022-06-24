if [ -n "${FQDN}" ]; then
  HOST_RULE="Host(\`${FQDN}\`)"
else
  HOST_RULE="Host(\`${PUBLIC_IP}\`)"
fi

if [ ${PUBLIC_PORT} -eq 443 ]; then
  ENTRYPOINT=websecure
else
  ENTRYPOINT=jitsi-meet
fi

cat <<EOF
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: argocd-server
  namespace: argocd
spec:
  entryPoints:
    - ${ENTRYPOINT}
  routes:
    - kind: Rule
      match: ${HOST_RULE} && PathPrefix(\`/argocd\`)
      services:
        - name: argocd-server
          port: 80
    - kind: Rule
      match: ${HOST_RULE} && PathPrefix(\`/argocd\`) && Headers(\`Content-Type\`, \`application/grpc\`)
      services:
        - name: argocd-server
          port: 80
          scheme: h2c
EOF
if [ -n "${CERT_RESOLVER}" ]; then
  cat <<EOF
  tls:
    certResolver: ${CERT_RESOLVER}
EOF
else
  cat <<EOF
  tls: {}
EOF
fi
