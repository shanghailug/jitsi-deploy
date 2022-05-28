if [ -n "${FQDN}" ]; then
  HOST_RULE="Host(\`${FQDN}\`)"
  TLS_CERT_RESOLVER="certResolver: ${CERT_RESOLVER}"
else
  HOST_RULE="Host(\`${PUBLIC_IP}\`)"
  TLS_MAP="{}"
fi

cat <<EOF
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: argocd-server
  namespace: argocd
spec:
  entryPoints:
    - websecure
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
  tls: ${TLS_MAP}
    ${TLS_CERT_RESOLVER}
EOF
