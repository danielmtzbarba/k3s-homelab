# Website Deployment

This document finishes the deployment of `danielmtz-website` onto the cluster.

Current assumptions:

- the cluster is working
- Traefik is working
- cert-manager is working
- the website image exists in GHCR
- the deployment uses the `stable` tag
- the domain is currently served from AWS S3

Current Kubernetes app path:

- `kubernetes/apps/danielmtz-website-tls/`

## 1. Verify The Image Exists

Before touching DNS, make sure the image you want to run is available:

- `ghcr.io/danielmtzbarba/danielmtz-website:stable`

Your deployment manifest already points to that tag in:

- `kubernetes/apps/danielmtz-website-tls/deployment.yaml`

## 2. Create The GHCR Pull Secret

Because the website repository is private, the cluster cannot pull the image anonymously.

Create the namespace first:

```bash
kubectl apply -f kubernetes/apps/danielmtz-website-tls/namespace.yaml
```

Then create the GHCR image pull secret inside that namespace:

```bash
kubectl create secret docker-registry ghcr-pull-secret \
  --namespace danielmtz-website \
  --docker-server=ghcr.io \
  --docker-username=YOUR_GITHUB_USERNAME \
  --docker-password=YOUR_GITHUB_PAT \
  --docker-email=YOUR_EMAIL
```

Notes:

- use a GitHub personal access token that can read packages
- the deployment already references `ghcr-pull-secret`
- do not commit the token or a generated secret manifest into the repository

## 3. Apply The Website Over HTTP First

Apply the website app:

```bash
kubectl apply -k kubernetes/apps/danielmtz-website-tls
```

Verify:

```bash
kubectl get pods -n danielmtz-website -o wide
kubectl get svc,ingress -n danielmtz-website
kubectl describe deployment danielmtz-website -n danielmtz-website
```

The pods should be `Running` and the service should point to them cleanly.

## 4. Get The Server Public IP

You need the public IP currently serving Traefik.

From this repo:

```bash
terraform -chdir=infra/terraform/server output server_public_ip
```

Or with `gcloud`:

```bash
gcloud compute instances describe "$SERVER_NAME" --zone="$ZONE" \
  --format='value(networkInterfaces[0].accessConfigs[0].natIP)'
```

## 5. Update Route53

Your domain is currently hosted through S3, so the DNS record is likely still pointing to:

- an S3 website endpoint
- or a CloudFront distribution in front of S3

You need to move the public DNS record to the GCP server public IP.

### Root Domain

For `danielmtzbarba.com`, change the Route53 record so it resolves to the server public IP.

If you currently have an alias record to S3 or CloudFront:

1. remove or replace that record
2. create an `A` record for `danielmtzbarba.com`
3. set the value to the GCP server public IP

### WWW Record

If you also use `www.danielmtzbarba.com`, decide now whether it should:

- point to the same server public IP
- or redirect to the apex domain somewhere else

The current website setup is intended to:

- serve `danielmtzbarba.com`
- redirect `www.danielmtzbarba.com` to `https://danielmtzbarba.com`

For that to work, simplest is:

- make both root and `www` point to the same public IP

The ingress and TLS configuration should include both hosts so the redirect also works cleanly over HTTPS.

## 6. Wait For DNS Propagation

Verify the domain resolves to the server public IP:

```bash
dig +short danielmtzbarba.com
```

Do not continue until it returns the GCP server IP.

## 7. Test HTTP On The Real Domain

Once DNS points to the cluster:

```bash
curl -I http://danielmtzbarba.com
curl http://danielmtzbarba.com
```

At this stage, the website should already be serving through the full app definition, including TLS ingress.

Useful checks:

```bash
kubectl get pods -n danielmtz-website -o wide
kubectl describe ingress danielmtz-website -n danielmtz-website
kubectl logs -n danielmtz-website deploy/danielmtz-website
```

## 8. Watch Certificate Issuance

Check:

```bash
kubectl get certificate
kubectl describe certificate danielmtzbarba-com-tls -n danielmtz-website
kubectl get orders.acme.cert-manager.io
kubectl get challenges.acme.cert-manager.io
```

If needed:

```bash
kubectl describe challenge
kubectl describe order
```

## 9. Test HTTPS

Once the certificate is ready:

```bash
curl -I https://danielmtzbarba.com
curl https://danielmtzbarba.com
```

## 10. Clean Up The Old S3 Hosting

Do not delete the old S3 website before the new cluster deployment is verified.

Safe sequence:

1. deploy on the cluster
2. point DNS to GCP
3. verify HTTP and HTTPS
4. verify browser access
5. only then remove or archive the old S3 website configuration

## Recommended Execution Order

1. create the namespace
2. create the GHCR pull secret
3. apply the website app
4. get the GCP server public IP
5. update Route53 away from S3 and toward the GCP IP
6. verify `danielmtzbarba.com` resolves correctly
7. verify certificate issuance
8. test HTTPS
9. retire the old S3-hosted path
