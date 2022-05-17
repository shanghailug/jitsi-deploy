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
      match: Host(\`${FQDN}\`) && PathPrefix(\`/argocd\`)
      services:
        - name: argocd-server
          port: 80
    - kind: Rule
      match: Host(\`${FQDN}\`) && PathPrefix(\`/argocd\`) && Headers(\`Content-Type\`, \`application/grpc\`)
      services:
        - name: argocd-server
          port: 80
          scheme: h2c
  tls:
    certResolver: ${CERT_RESOLVER}
EOF
