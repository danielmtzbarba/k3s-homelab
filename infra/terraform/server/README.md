# Terraform Server Stack

This stack provisions only the first GCP server foundation:

- custom VPC
- subnet
- firewall rules
- static external IP
- service account for VM logging and metrics
- SSH access metadata
- single Ubuntu VM

It does not install k3s for you yet.

That separation is intentional:

- Terraform owns infrastructure
- you still learn k3s installation manually

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
```

Then SSH into the VM and install k3s manually.
