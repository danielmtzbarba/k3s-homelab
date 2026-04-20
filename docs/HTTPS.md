# HTTPS

This document adds HTTPS to the cluster using:

- `cert-manager`
- Let's Encrypt
- Traefik HTTP-01 challenge solving

This assumes:

- the target website hostname already points to the server public IP
- plain HTTP access to the site already works before TLS is enabled

## 1. Verify DNS First

From your local machine:

```bash
dig +short danielmtzbarba.com
curl http://danielmtzbarba.com
```

Do not continue until both work.

## 2. Install Helm If Needed

On your local machine, verify Helm exists:

```bash
helm version
```

If it is missing on Arch Linux:

```bash
sudo pacman -S helm
```

## 3. Install cert-manager

cert-manager upstream currently recommends the OCI Helm chart. The current chart version in the official docs is `v1.20.2`.

Manual install:

```bash
helm install \
  cert-manager oci://quay.io/jetstack/charts/cert-manager \
  --version v1.20.2 \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true
```

Verify:

```bash
kubectl get pods -n cert-manager
```

Expected result:

- `cert-manager`
- `cert-manager-cainjector`
- `cert-manager-webhook`

all in `Running` state

Automated equivalent:

```bash
sh scripts/infra.sh deploy-addons
```

That script:

- verifies `helm`, `kubectl`, and local kubeconfig
- installs or upgrades `cert-manager`
- waits for the `cert-manager` deployments
- applies the Let's Encrypt `ClusterIssuer`

## 4. Create the Let's Encrypt ClusterIssuer

Before applying it, edit the email in:

```bash
kubernetes/platform/issuers/letsencrypt-prod.yaml
```

Use a real email address you control for Let's Encrypt expiry notices.

Apply:

```bash
kubectl apply -f kubernetes/platform/issuers/letsencrypt-prod.yaml
```

Verify:

```bash
kubectl get clusterissuer
kubectl describe clusterissuer letsencrypt-prod
```

## 5. Apply The App TLS Ingress

Apply:

```bash
kubectl apply -k kubernetes/apps/danielmtz-website-tls
```

`deploy-addons` does not apply application ingresses. Keep platform add-ons and app TLS manifests separate.

Verify:

```bash
kubectl get ingress
kubectl get certificate
kubectl get certificaterequest
kubectl get order
kubectl get challenge
```

## 6. Wait for Certificate Issuance

The certificate flow is:

- Ingress created
- cert-manager creates a `Certificate`
- cert-manager creates ACME `Order` and `Challenge` resources
- Traefik serves the HTTP-01 challenge response
- Let's Encrypt validates the domain
- the TLS secret is created

Watch:

```bash
kubectl get certificate -w
kubectl get orders.acme.cert-manager.io -w
kubectl get challenges.acme.cert-manager.io -w
```

Once ready:

Expected result:

- the relevant certificate becomes `Ready: True`

## 7. Test HTTPS

From your local machine:

```bash
curl -I https://danielmtzbarba.com
curl https://danielmtzbarba.com
```

## 8. Common Failure Cases

### DNS does not resolve to the server IP

Fix Route53 first.

### HTTP works by IP but not by hostname

That is still a DNS problem.

### Challenge stays pending

Check:

```bash
kubectl describe challenge
kubectl describe order
kubectl describe certificaterequest
```

### Certificate not created

Check Traefik and cert-manager:

```bash
kubectl get pods -n cert-manager
kubectl logs -n cert-manager deploy/cert-manager
kubectl logs -n kube-system deploy/traefik
```

## 9. Cleanup

If you want to remove HTTPS for the echo app only:

```bash
kubectl delete -k kubernetes/apps/danielmtz-website-tls
```

If you also want to remove the issuer:

```bash
kubectl delete -f kubernetes/platform/issuers/letsencrypt-prod.yaml
```

Sources:

- [cert-manager Helm install docs](https://cert-manager.io/docs/installation/helm/)
- [cert-manager HTTP01 docs](https://cert-manager.io/docs/configuration/acme/http01/)
