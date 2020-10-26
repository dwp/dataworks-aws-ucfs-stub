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

variable "ucfs_server_stub_ec2_instance_type" {
  default = {
    development = "t3.large"
    qa          = "t3.large"
    integration = "c5.large"
    preprod     = "c5.large"
  }
}

variable "ucfs_server_stub_ebs_volume_size" {
  default = {
    development = "10"
    qa          = "10"
    integration = "500"
    preprod     = "500"
  }
}

variable "ucfs_server_stub_ebs_volume_type" {
  default = {
    development = "gp2"
    qa          = "gp2"
    integration = "gp2"
    preprod     = "gp2"
  }
}


variable "al2_hardened_ami_id" {
  description = "The AMI ID of the latest/pinned Hardened AMI AL2 Image"
  type        = string
}