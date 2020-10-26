resource "aws_launch_template" "ucfs_server_stub" {
  name_prefix   = "ucfs_server_stub_"
  image_id      = var.al2_hardened_ami_id
  instance_type = var.ucfs_server_stub_ec2_instance_type[local.environment]
  vpc_security_group_ids = [
  aws_security_group.ucfs_server_stub.id]
  user_data                            = base64encode(join("", data.template_file.ucfs_server_stub.*.rendered))
  instance_initiated_shutdown_behavior = "terminate"

  iam_instance_profile {
    arn = join("", aws_iam_instance_profile.ucfs_server_stub.*.arn)
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.ucfs_server_stub_ebs_volume_size
      volume_type           = var.ucfs_server_stub_ebs_volume_type
      delete_on_termination = true
      encrypted             = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    local.common_tags,
    {
      Name        = "ucfs_server_stub"
      Persistence = "Ignore"
    }
  )
  tag_specifications {
    resource_type = "instance"

    tags = merge(
      local.common_tags,
      {
        Name        = "ucfs_server_stub"
        Application = "ucfs_server_stub"
        Persistence = "Ignore"
      }
    )
  }

}

resource "aws_iam_role" "ucfs_server_stub" {
  name               = "ucfs_server_stub"
  count              = local.deploy_ucfs_server_stub[local.environment] ? 1 : 0
  assume_role_policy = join("", data.aws_iam_policy_document.ucfs_server_stub_assume_role.*.json) #data.aws_iam_policy_document.ucfs_server_stub_assume_role.json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "ucfs_server_stub_assume_role" {
  count = local.deploy_ucfs_server_stub[local.environment] ? 1 : 0

  statement {
    sid = "EC2AssumeRole"
    principals {
      identifiers = [
      "ec2.amazonaws.com"]
      type = "Service"
    }
    actions = [
      "sts:AssumeRole"
    ]
  }
}

resource "aws_iam_instance_profile" "ucfs_server_stub" {
  count = local.deploy_ucfs_server_stub[local.environment] ? 1 : 0
  name  = "ucfs_server_stub"
  role  = join("", aws_iam_role.ucfs_server_stub.*.name)#aws_iam_role.ucfs_server_stub.name
}

resource "aws_security_group" "ucfs_server_stub" {
  name        = "ucfs_server_stub"
  description = "Control access to and from UCFS export server stub"
  vpc_id      = data.terraform_remote_state.ingest.outputs.stub_ucfs_vpc.id

  tags = merge(
    local.common_tags,
    {
      "Name" = "ucfs_server_stub"
    }
  )
}

data "template_file" "ucfs_server_stub" {
  count    = local.deploy_ucfs_server_stub[local.environment] ? 1 : 0
  template = file("ucfs_server_stub_userdata.tpl")
}