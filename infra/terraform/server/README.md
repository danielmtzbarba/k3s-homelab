# Terraform Server Stack

This stack provisions only the first GCP server foundation:

- custom VPC
- subnet
- firewall rules
- static external IP
- reserved internal IP
- service account for VM logging and metrics
- dedicated GCP service account and key for External Secrets Operator GCPSM access
- SSH access metadata
- single Ubuntu VM
- cloud-init bootstrap for optional Tailscale enrollment
- cloud-init bootstrap for `k3s server`

This stack now bootstraps the server node directly at VM boot through cloud-init.

The server cloud-init path can:

- configure required kernel modules and sysctls
- join Tailscale when `TAILSCALE_ENABLE=true`
- install `k3s server`
- configure `tls-san` for public and Tailscale IPs
- configure the Kubernetes service-account issuer when enabled

Argo CD and the rest of the platform are still installed after cluster access is available. They are not part of server cloud-init.

## Files

- `versions.tf`: Terraform requirements, provider pinning, and backend declaration
- `providers.tf`: GCP provider configuration
- `variables.tf`: input variables
- `terraform.tfvars.example`: sample values
- `main.tf`: resources
- `outputs.tf`: useful outputs
- `backend.hcl.example`: sample GCS backend config
- `generate_tf_files.sh`: generates `terraform.auto.tfvars` and `backend.hcl` from the root `.env`

## Usage

```bash
cd infra/terraform/server
bash generate_tf_files.sh
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

After apply:

```bash
terraform output
terraform output ssh_command
terraform output eso_gcpsm_service_account_email
```

Then verify:

```bash
terraform output server_private_ip
```

If `K3S_CLUSTER_TOKEN` and optional Tailscale settings are configured in `.env`, the server should come up already running `k3s`.

If `ESO_GCPSM_ENABLE=true` (default), this stack also writes a local JSON key file for
External Secrets Operator at:

```bash
terraform output eso_gcpsm_key_output_path
```

That file is used by `scripts/setup_tailscale_operator_secret_stack.sh` to create
`external-secrets/gcpsm-secret`.

Important:

- key creation is disabled by default with `ESO_GCPSM_KEY_CREATE=false`
- this is required in projects/orgs enforcing `constraints/iam.disableServiceAccountKeyCreation`
- if you enable key creation, the key material is written to local disk and also exists in Terraform state
- protect the tfstate bucket accordingly
