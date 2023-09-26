resource "random_string" "rnd_deploy_id" {
  length  = 11
  special = false
  upper   = false #s3 bucket naming rules don't allow upper case
  #keepers will allow generating a new rnd_deploy_id when the deployment_prefix is changed; comment out if not required
  keepers = {
    deployment_prefix = var.deployment_prefix
  }
}

locals {
  #deployment_id = join("-", [var.deployment_prefix, random_string.rnd_deploy_id.id]) #uncomment if random_string keepers is not used;
  deployment_id = join("-", [random_string.rnd_deploy_id.keepers.deployment_prefix, random_string.rnd_deploy_id.id]) #this goes with the random_string keepers block; comment out if keepers is not used;
}
