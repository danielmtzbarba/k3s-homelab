# Infrastructure Bootstrap

This document is the single operator guide for the first infrastructure phase.

Scope:

- create a GCP project
- authenticate locally
- prepare `.env`
- create the Terraform backend bucket
- enable required GCP APIs
- provision the first server infrastructure with Terraform

This does not install application services.

This does not create a worker node.

This document stops at SSH verification.

You can run the Terraform workflow manually, or use the thin wrapper script:

```bash
sh scripts/infra.sh bootstrap
sh scripts/infra.sh plan
sh scripts/infra.sh apply
sh scripts/infra.sh kubeconfig
```

`kubeconfig` now also copies and runs the VM-side k3s server setup script before fetching the kubeconfig, so it can reconcile a freshly rebuilt server.

For a full reset test, there is also:

```bash
sh scripts/infra.sh nuke
```

That destroys both the server stack and the backend bucket stack, in the correct order.

## 1. Create a GCP Project

If you do not already have a project, create one in the Google Cloud Console.

Suggested shape:

- billing enabled
- project name: `k3s-homelab`
- project id: your own unique id, for example `k3s-homelab-danielmtz`

After the project exists, note the project id.

## 2. Install and Login to the CLIs

You need:

- `gcloud`
- `terraform`

Verify they exist:

```bash
gcloud version
terraform version
```

Login with `gcloud`:

```bash
gcloud auth login
gcloud auth application-default login
```

Set the active project:

```bash
gcloud config set project "your-gcp-project-id"
```

Example:

```bash
gcloud config set project "k3s-homelab-danielmtz"
```

Enable the required project services:

```bash
gcloud services enable storage.googleapis.com compute.googleapis.com
```

## 3. Create `.env`

From the repository root:

```bash
cp .env.example .env
```

Fill in `.env`.

Recommended Germany-friendly values:

```bash
PROJECT_ID="your-gcp-project-id"
REGION="europe-west3"
ZONE="europe-west3-a"
NETWORK_NAME="k3s-lab"
SUBNET_NAME="k3s-lab-subnet"
SUBNET_CIDR="10.42.0.0/24"
SERVER_NAME="k3s-server-1"
SERVER_TAG="k3s-server"
ADDRESS_NAME="k3s-server-ip"
MACHINE_TYPE="e2-standard-2"
IMAGE_FAMILY="ubuntu-2404-lts-amd64"
IMAGE_PROJECT="ubuntu-os-cloud"
SSH_SOURCE_RANGE="203.0.113.10/32"
SSH_USER="your-user"
SSH_PUBLIC_KEY_PATH="$HOME/.ssh/id_ed25519.pub"
BOOT_DISK_SIZE_GB="40"
TF_STATE_BUCKET="your-project-id-k3s-homelab-tfstate"
TF_STATE_PREFIX="server"
TF_STATE_LOCATION="EUROPE-WEST3"
TF_STATE_DELETE_OLD_VERSIONS="false"
TF_STATE_NONCURRENT_VERSION_AGE_DAYS="90"
TF_STATE_FORCE_DESTROY="false"
```

Notes:

- `REGION` and `ZONE` are for Compute Engine and should stay lowercase
- `TF_STATE_LOCATION` is for Cloud Storage and should use the bucket location code
- for Frankfurt, use `EUROPE-WEST3`
- `90` days is a good default for old Terraform state object versions if you later enable cleanup
- keep `TF_STATE_FORCE_DESTROY="false"` unless you intentionally want full bucket teardown

If you do not know your public IP:

```bash
curl ifconfig.me
```

Then set `SSH_SOURCE_RANGE` using CIDR format, for example:

```bash
SSH_SOURCE_RANGE="203.0.113.10/32"
```

Load the file into your shell:

```bash
set -a
source .env
set +a
```

## 4. Bootstrap the Terraform Backend Bucket

The backend bucket is created by a separate Terraform stack that uses local state.

That is intentional. The remote backend cannot be used before it exists.

Go to the bootstrap stack:

```bash
cd infra/terraform/bootstrap
```

Generate the Terraform input file from `.env`:

```bash
bash generate_tf_files.sh
```

Initialize Terraform:

```bash
terraform init
```

Plan:

```bash
terraform plan
```

Apply:

```bash
terraform apply
```

Wrapper equivalent:

```bash
sh scripts/infra.sh bootstrap
```

Expected result:

- one GCS bucket
- versioning enabled
- uniform bucket-level access enabled

## 5. Common Failure Cases Before Server Apply

### Backend bucket location fails

If Cloud Storage rejects the bucket location, use an uppercase bucket location code such as:

```bash
TF_STATE_LOCATION="EUROPE-WEST3"
```

Do not confuse this with Compute Engine region formatting.

Correct examples:

- Compute Engine region: `europe-west3`
- Compute Engine zone: `europe-west3-a`
- Cloud Storage bucket location: `EUROPE-WEST3`

### Compute API disabled

If Terraform fails creating network or IP resources with `SERVICE_DISABLED`, run:

```bash
gcloud services enable compute.googleapis.com
```

Then wait a few minutes and rerun:

```bash
terraform apply
```

Wrapper equivalents:

```bash
sh scripts/infra.sh plan
sh scripts/infra.sh apply
```

Do not manually delete partially created Terraform resources unless you know exactly what you are doing.

## 6. Provision the Server Infrastructure

Go to the server stack:

```bash
cd ../server
```

Generate Terraform files from `.env`:

```bash
bash generate_tf_files.sh
```

Initialize Terraform with the backend config generated from `.env`:

```bash
terraform init -backend-config=backend.hcl
```

Plan:

```bash
terraform plan
```

Apply:

```bash
terraform apply
```

This stack creates:

- VPC
- subnet
- firewall rules
- static external IP
- VM service account
- single Ubuntu VM

If `compute.googleapis.com` was just enabled, wait a minute or two before retrying Terraform if GCP still reports it as disabled.

## 7. Inspect the Terraform Outputs

After apply:

```bash
terraform output
terraform output ssh_command
```

Useful direct output:

```bash
terraform output server_public_ip
terraform output server_name
```

## 8. Verify the VM with gcloud

You can verify the instance directly:

```bash
gcloud compute instances list
gcloud compute instances describe "$SERVER_NAME" --zone="$ZONE"
```

## 9. SSH Into the Server

Use the Terraform output or run:

```bash
gcloud compute ssh "$SERVER_NAME" --zone="$ZONE"
```

This is the end of the infrastructure phase.

Continue with [K3S_SERVER_SETUP.md](/home/danielmtz/Projects/kubernetes/k3s-homelab/docs/K3S_SERVER_SETUP.md:1) after SSH succeeds.
