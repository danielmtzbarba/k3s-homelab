# ESO On GCP With Workload Identity Federation

This document is retained for reference only.

The current recommended path in this repository is a dedicated GCP service
account credential stored in `external-secrets/gcpsm-secret`, because the k3s
API issuer in this homelab is private and not a good fit for Google Workload
Identity Federation automation.

This document defines the clean path for using External Secrets Operator with Google Cloud Secret Manager on this self-managed k3s cluster without long-lived service account keys.

## Goal

Use:

- Kubernetes service account tokens
- Google Workload Identity Federation
- GCP Secret Manager
- External Secrets Operator

Do not use:

- long-lived JSON service account keys stored in Kubernetes
- plaintext application secrets in Git
- manual `kubectl create secret` as the steady-state workflow

## Is ESO Safe?

Yes, if you treat it as a privileged platform controller and scope it carefully.

Good:

- avoids long-lived service account keys in the cluster
- centralizes secret delivery from GCP Secret Manager
- supports short-lived authentication through Workload Identity Federation

Required guardrails:

- use a dedicated Kubernetes service account for secret access
- grant only `roles/secretmanager.secretAccessor` on the specific secrets or narrowest project scope you can
- do not let every namespace manage arbitrary `ClusterSecretStore` resources
- treat `ExternalSecret` creation as privileged platform state

## Architecture

The final auth path is:

1. k3s issues a projected service account token for `external-secrets/eso-gcpsm`
2. the token contains the configured Kubernetes service-account issuer
3. Google IAM trusts that issuer and the uploaded JWKS
4. ESO exchanges the token through Workload Identity Federation
5. ESO reads values from GCP Secret Manager
6. ESO materializes normal Kubernetes `Secret` objects for workloads and platform controllers

## 1. Enable A Stable Kubernetes Service-Account Issuer

Google WIF for self-managed Kubernetes requires a stable Kubernetes service-account issuer and the cluster JWKS.

The repo now supports optional issuer config through `.env`:

```bash
K8S_SERVICE_ACCOUNT_ISSUER_ENABLE="true"
K8S_SERVICE_ACCOUNT_ISSUER_URL="https://k3s-server-1.<your-tailnet>.ts.net:6443"
K8S_SERVICE_ACCOUNT_JWKS_URI="https://k3s-server-1.<your-tailnet>.ts.net:6443/openid/v1/jwks"
```

Recommendations:

- use a stable HTTPS URL
- prefer a stable tailnet MagicDNS hostname if you already use Tailscale for private admin access
- keep the issuer URL stable over time; changing it invalidates the old trust relationship

Apply the config:

```bash
sh scripts/infra.sh server-setup
sh scripts/infra.sh kubeconfig
```

Verify:

```bash
KUBECONFIG="$HOME/.kube/config-k3s-lab" kubectl get --raw /.well-known/openid-configuration
KUBECONFIG="$HOME/.kube/config-k3s-lab" kubectl get --raw /openid/v1/jwks
```

The issuer URL must match the URL you configured above.

## 2. Create The Google Workload Identity Pool And Provider

You only do this once per cluster.

First, export your GCP project values:

```bash
PROJECT_ID="your-gcp-project-id"
PROJECT_NUMBER="$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')"
POOL_ID="k3s-homelab"
PROVIDER_ID="k3s-server-1"
```

Download the cluster JWKS:

```bash
KUBECONFIG="$HOME/.kube/config-k3s-lab" \
kubectl get --raw /openid/v1/jwks > cluster-jwks.json
```

Create the pool:

```bash
gcloud iam workload-identity-pools create "$POOL_ID" \
  --location="global" \
  --display-name="k3s homelab" \
  --description="Workload Identity Federation for the k3s homelab cluster"
```

Create the provider:

```bash
gcloud iam workload-identity-pools providers create-oidc "$PROVIDER_ID" \
  --location="global" \
  --workload-identity-pool="$POOL_ID" \
  --issuer-uri="$K8S_SERVICE_ACCOUNT_ISSUER_URL" \
  --attribute-mapping="google.subject=assertion.sub,attribute.namespace=assertion['kubernetes.io']['namespace'],attribute.service_account_name=assertion['kubernetes.io']['serviceaccount']['name']" \
  --attribute-condition="assertion['kubernetes.io']['namespace']=='external-secrets' && assertion['kubernetes.io']['serviceaccount']['name']=='eso-gcpsm'" \
  --jwk-json-path="cluster-jwks.json"
```

Why this condition exists:

- it restricts the provider to the `external-secrets/eso-gcpsm` identity
- that keeps the trust boundary tight

## 3. Grant GCP Access To The Kubernetes Service Account Identity

Create or choose the secrets you want ESO to read.

For a narrow first step, grant access only to the first platform secrets rather than the whole project.

Example for one secret:

```bash
gcloud secrets add-iam-policy-binding k3s-ts-oauth-client-id \
  --project="$PROJECT_ID" \
  --role="roles/secretmanager.secretAccessor" \
  --member="principal://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}/subject/system:serviceaccount:external-secrets:eso-gcpsm"
```

If you choose project-wide access instead:

```bash
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --role="roles/secretmanager.secretAccessor" \
  --member="principal://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}/subject/system:serviceaccount:external-secrets:eso-gcpsm"
```

That is easier, but broader than ideal.

Preferred model:

- bind each secret to the exact Kubernetes service-account subject principal
- do not use broader project-wide access unless you are intentionally trading security for setup speed

Recommended helper variable:

```bash
ESO_PRINCIPAL="principal://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}/subject/system:serviceaccount:external-secrets:eso-gcpsm"
```

Then use:

```bash
gcloud secrets add-iam-policy-binding k3s-ts-oauth-client-id \
  --project="$PROJECT_ID" \
  --role="roles/secretmanager.secretAccessor" \
  --member="$ESO_PRINCIPAL"
```

## 4. Apply The Kubernetes Service Account

The repo now includes:

- [serviceaccount-gcpsm.yaml](/home/danielmtz/Projects/kubernetes/k3s-homelab/kubernetes/platform/external-secrets/serviceaccount-gcpsm.yaml)

Apply it:

```bash
KUBECONFIG="$HOME/.kube/config-k3s-lab" \
kubectl apply -f kubernetes/platform/external-secrets/serviceaccount-gcpsm.yaml
```

## 5. Create The ClusterSecretStore

The repo includes a template:

- [clustersecretstore-gcpsm-wif.example.yaml](/home/danielmtz/Projects/kubernetes/k3s-homelab/kubernetes/platform/external-secrets/clustersecretstore-gcpsm-wif.example.yaml)

Copy the values into a real manifest and replace:

- `PROJECT_NUMBER`
- `POOL_ID`
- `PROVIDER_ID`
- `your-gcp-project-id`

Target structure:

```yaml
apiVersion: external-secrets.io/v1
kind: ClusterSecretStore
metadata:
  name: gcp-secret-manager
spec:
  provider:
    gcpsm:
      projectID: your-gcp-project-id
      auth:
        workloadIdentityFederation:
          audience: //iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/POOL_ID/providers/PROVIDER_ID
          serviceAccountRef:
            name: eso-gcpsm
            namespace: external-secrets
            audiences:
              - //iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/POOL_ID/providers/PROVIDER_ID
```

Apply it:

```bash
KUBECONFIG="$HOME/.kube/config-k3s-lab" \
kubectl apply -f <your-real-clustersecretstore-manifest>.yaml
```

## 6. First ExternalSecret

After the store exists, your first migration target should be the Tailscale operator OAuth secret.

That will let you replace:

- local bootstrap values in `.env` for `TAILSCALE_OAUTH_CLIENT_ID`
- local bootstrap values in `.env` for `TAILSCALE_OAUTH_CLIENT_SECRET`

with:

- `ExternalSecret` -> `tailscale/operator-oauth`

The repo now includes an operator-focused wrapper that performs the first working path end to end:

```bash
cp .env.example .env
sh scripts/setup_tailscale_operator_secret_stack.sh
sh scripts/infra.sh deploy-tailscale-operator
```

That wrapper:

- syncs the configured secrets to GCP Secret Manager
- reapplies per-secret IAM bindings
- applies `external-secrets/eso-gcpsm`
- renders and applies the `ClusterSecretStore`
- applies the Tailscale `ExternalSecret`
- waits for `tailscale/operator-oauth`

## Operational Notes

- The cluster does not need to be reachable from the internet for this pattern. Google IAM can trust the issuer while you upload the cluster JWKS directly.
- If you rotate the k3s service-account signing key, you must update the JWKS in Google if the key set changes.
- Do not casually change the issuer URL after the provider is created.

## References

- [Google: Configure Workload Identity Federation with Kubernetes](https://docs.cloud.google.com/iam/docs/workload-identity-federation-with-kubernetes)
- [Kubernetes: Service account issuer discovery](https://v1-32.docs.kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/)
- [Kubernetes API server flags](https://v1-34.docs.kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/)
- [ESO: Google Cloud Secret Manager provider](https://external-secrets.io/main/provider/google-secrets-manager/)
