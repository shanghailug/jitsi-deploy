# Installation

The deployment script is largely based on the helm chart [jitsi-helm](https://github.com/jitsi-contrib/jitsi-helm/). The dependencies include [k3s](https://k3s.io/), [traefik](https://traefik.io/) and [argocd](https://argoproj.github.io/). It also uses [Let's Encrypt](https://letsencrypt.org/) for signing TLS certificates. 

## Prerequisites

  * A GNU/Linux host with Debian/Ubuntu installed and root privileges
  * The host has a public IPv4 address <PUBLIC_IP>
  * Allow these traffic through firewall: 80/TCP, 443/TCP, 5222/TCP (necessary only for external jvb), 30000/UDP (30001/UDP for test)
  * An email inbox address <ACME_EMAIL> for receiving ACME notification mails
  * A domain name <PROD_HOSTNAME> that has a DNS A record pointing to <PUBLIC_IP>
  * (optional) Another domain name <TEST_HOSTNAME> (for test deployment purposes) that has a DNS A record pointing to <PUBLIC_IP>
  * (optional) Yet another domain name <CD_HOSTNAME> (for accessing the ArgoCD web UI) that has a DNS A record pointing to <PUBLIC_IP>

## Install/Upgrade

The initial installation needs to be run from command line. But afterwards, ArgoCD web UI can be used instead to fulfill the subsequent (re)install/upgrade/uninstall needs. **All the shell commands need to be run with root user.** There are two installation modes, prod and test. By default, prod is installed. It can be switched to test by setting environment variable `TEST_INSTALL`.

### Install/Upgrade from command line

Run the following shell command by providing the 2 mandatory arguments: fully-qualified domain name for accessing jitsi web, and an email address for receiving Let's Enrypt's ACME mails. 

```bash
curl -sL https://raw.githubusercontent.com/shanghailug/jitsi-deploy/master/deploy_jitsi.sh | 
  bash -s - <PROD_HOSTNAME> <ACME_EMAIL>
```

Alternatively, an additional environment variable `ARGOCD_FQDN` can be provided to enable ArgoCD web server's ingress, so that it can be accessed post installation, for future operations: 

```bash
curl -sL https://raw.githubusercontent.com/shanghailug/jitsi-deploy/master/deploy_jitsi.sh | 
  ARGOCD_FQDN=<CD_HOSTNAME> bash -s - <PROD_HOSTNAME> <ACME_EMAIL>
```

Before committing to a prod installation, the whole setup can be tested by using a test hostname, only requesting certificates from staging instance of Let's Encrypt, and installing into `test` k8s namespace. This can be done by setting `TEST_INSTALL` and `STAGING_CERT` environment variable and giving test hostname as command argument, like this: 

```bash
curl -sL https://raw.githubusercontent.com/shanghailug/jitsi-deploy/master/deploy_jitsi.sh | 
  TEST_INSTALL=1 STAGING_CERT=1 ARGOCD_FQDN=<CD_HOSTNAME> bash -s - <TEST_HOSTNAME> <ACME_EMAIL>
```

The installed applications can then be updated/upgraded by rerunning exactly the same command, when the git repo is updated or it's desirable to enable ArgoCD web after initial installation is done. The already installed components will usually be kept as-is if their versions matche, or be upgraded otherwise. If k3s needs to be upgraded, however, it's probably a better idea to [tear down](#tear-down) the whole setup before-hand. 

### Install/Upgrade from ArgoCD web UI

If the initial installation enabled ArgoCD web UI's ingress by providing the environment variable `ARGOCD_FQDN`, then the ArgoCD web server can be accessed via `https://${ARGOCD_FQDN}/`. 
Please refer to [ArgoCD docs](https://argo-cd.readthedocs.io/en/stable/getting_started/#6-create-an-application-from-a-git-repository) for more details about how to create/update applications using helm charts from a git repo. The login's name is `admin` and the login's password can be retrieved after initial installation, by running the following command on the host: 

```bash
kubectl -n argocd get secret/argocd-initial-admin-secret -o jsonpath='{ .data.password }' | base64 -d
```

## Settings

The following list of environment variables can be used to customize or alter the installation. 

Environment Variable | Description | Default Value | Default behaviour
--- | --- | --- | ---
`ARGOCD_FQDN` | fully-qualified hostname for accessing ArgoCD web UI | "" | don't enable web ingress for ArgoCD server
`ARGOCD_VERSION` | argocd release to install | "v2.3.3" | 
`DEPLOY_GIT_REPO` | the git repo url for retrieving artifacts | `https://github.com/shanghailug/jitsi-deploy.git` |
`DEPLOY_GIT_VERSION` | the revision of artifacts to checkout and use from the repo | "" | use the default branch when git repo is cloned locally
`EXCLUDE_JVB` | Exclude built-in jvb component (so that an external one can be registered for use) | "" | include jvb
`K3S_VERSION` | k3s release to install | "v1.23.6+k3s1" | 
`TEST_INSTALL` | when set to non-empty, install an app called `jitsitest` into `test` k8s namespace | "" | install an app called `jitsi` into `prod` k8s namespace


## Uninstall

### Uninstall the applications

The applications can be uninstalled either from ArgoCD web UI or by running something like the following commands: 

```bash
argocd app delete jitsi
argocd app delete jitsitest
```

### Tear down

```bash
/usr/local/bin/k3s-uninstall.sh
```
