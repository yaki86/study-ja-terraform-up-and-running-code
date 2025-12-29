provider "aws" {
  region = "us-east-2"
}

module "webserver_cluster" {
  source = "../../../../modules/services/webserver-cluster"

  ami         = "ami-0fb653ca2d3203ac1"
  server_text = "New server text"

  cluster_name           = "webservers-stg"
  db_remote_state_bucket = "202512-yaki-terraform-up-and-running-state"
  db_remote_state_key    = "stage/data-stores/mysql/terraform.tfstate"

  instance_type = "t2.micro"
  min_size      = 2
  max_size      = 2

  custom_tags = {
    Owner      = "team-stg"
    DeployedBy = "Terraform"
  }

  enable_autoscaling = false
}

module "iam" {
  source   = "../../../../global/iam"
  for_each = toset(var.user_names)
  name     = each.value
}

output "for_directive" {
  value = "%{for name in var.user_names}${name},%{endfor}"
}

