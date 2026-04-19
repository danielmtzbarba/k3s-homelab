# Terraform Bootstrap Stack

This stack bootstraps the Terraform backend bucket.

It uses local state on purpose.

That is the correct design because the remote backend does not exist yet.

## What It Creates

- one GCS bucket for Terraform state
- uniform bucket-level access
- object versioning
- optional lifecycle cleanup for older object versions

## Usage

```bash
cd infra/terraform/bootstrap
bash generate_tf_files.sh
terraform init
terraform plan
terraform apply
```

After this bucket exists, move to `infra/terraform/server/` and use the generated `backend.hcl`.

## Important Rule

Do not configure a remote backend in this stack.

This stack should remain local-state and minimal.
