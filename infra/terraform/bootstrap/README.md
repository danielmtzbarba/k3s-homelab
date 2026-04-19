# Terraform Bootstrap Stack

This stack bootstraps the Terraform backend bucket.

It uses local state on purpose.

That is the correct design because the remote backend does not exist yet.

## What It Creates

- one GCS bucket for Terraform state
- uniform bucket-level access
- object versioning
- optional lifecycle cleanup for older object versions
- optional force-destroy behavior for full reset testing

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

## Force Destroy

By default, the backend bucket is protected from deletion while it still contains Terraform state objects.

That is the correct default.

If you want full reset behavior for testing, set this in `.env`:

```bash
TF_STATE_FORCE_DESTROY="true"
```

Only do that intentionally. It allows Terraform to delete the backend bucket even when it still contains state objects and versions.
