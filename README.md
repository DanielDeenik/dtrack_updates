# DTrack

## Architecture

## Using this repo
- Dependencies:
  - Setup AWS account, and IAM user, with policies (attach EC2 Full Access) -- TODO: Manage Terraform policies better
  - User AWS CLI to configure account
  - Install Terraform
  - Install Ansible
  - Github CLI (or otherwise get Github API token)
  - Setup Cloudflare and add a domain as zone (get Cloudflare API token)
- Clone repo (potentially some permissions are required if not public, and potentially you would want to fork it first, and clone your fork)
- If setting up for the first time, generate key pairs (else get existing keys securely):
  - `mkdir -p private/keys/instance private/keys/deploy`
  - `ssh-keygen -t ed25519 -C "deankayton@gmail.com" -f private/keys/instance/id`
  - `ssh-keygen -t ed25519 -C "deankayton@gmail.com" -f private/keys/deploy/id`
- `cp terraform.tfvars.tpl terraform.tfvars` and modify what is applicable (mainly Cloudflare and Github token)
- Provision Infrastructure (`terraform init` and `terraform apply` from root of repo)
- Change workspace to 'prod' `terraform workspace new prod` and `terraform workspace select prod` and repeat last step
- Staging is the default, so to go back, `terraform workspace select default`
- It is possible to use Ansible to provision staging and prod simultaneously
