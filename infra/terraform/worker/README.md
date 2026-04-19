# Terraform Worker Stack

This stack provisions the first k3s worker VM.

It assumes the server stack already created:

- the VPC
- the subnet
- the node firewall rules

This stack only creates:

- one VM service account
- one Ubuntu VM for the worker

## Usage

```bash
cd infra/terraform/worker
bash generate_tf_files.sh
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

After apply, use the worker join helper:

```bash
sh scripts/worker.sh join
```
