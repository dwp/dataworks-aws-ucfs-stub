variable "costcode" {
  type    = string
  default = ""
}

variable "assume_role" {
  type        = string
  default     = "ci"
  description = "IAM role assumed by Concourse when running Terraform"
}

variable "region" {
  type    = string
  default = "eu-west-2"
}

variable "stub_ucfs_export_server_ec2_instance_type" {
  default = {
    development = "t3.large"
    qa          = "t3.large"
    integration = "t3.large"
    preprod     = "t3.large"
    production  = "c5.large"
  }
}

variable "stub_ucfs_export_server_ebs_volume_size" {
  default = {
    development = "10"
    qa          = "10"
    integration = "500"
    preprod     = "500"
    production  = "500"
  }
}

variable "stub_ucfs_export_server_ebs_volume_type" {
  default = {
    development = "gp2"
    qa          = "gp2"
    integration = "gp2"
    preprod     = "gp2"
    production  = "gp2"
  }
}

variable "al2_hardened_ami_id" {
  description = "The AMI ID of the latest/pinned Hardened AMI AL2 Image"
  type        = string
}
