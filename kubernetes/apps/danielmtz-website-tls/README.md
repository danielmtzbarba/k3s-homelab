# Danielmtz Website TLS Variant

This directory is an explicit "website + TLS" app variant.

It exists to make the configuration difference obvious compared to:

- the previous split HTTP/TLS website layout

The key difference is the ingress definition:

- the base app uses plain HTTP ingress
- this variant includes:
  - `cert-manager.io/cluster-issuer: letsencrypt-prod`
  - a `tls:` block
  - both `danielmtzbarba.com` and `www.danielmtzbarba.com`

Use this variant when you want a single apply target that already includes TLS:

```bash
kubectl apply -k kubernetes/apps/danielmtz-website-tls
```
