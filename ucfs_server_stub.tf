resource "aws_launch_template" "ucfs_server_stub" {
  count         = local.deploy_ucfs_server_stub[local.environment] ? 1 : 0
  name_prefix   = "ucfs_server_stub_"
  image_id      = var.al2_hardened_ami_id
  instance_type = var.ucfs_server_stub_ec2_instance_type[local.environment]
  vpc_security_group_ids = [
  aws_security_group.ucfs_server_stub.id]
  user_data                            = base64encode(data.template_file.ucfs_server_stub[0].rendered)
  instance_initiated_shutdown_behavior = "terminate"

  iam_instance_profile {
    arn = aws_iam_instance_profile.ucfs_server_stub[0].arn
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.ucfs_server_stub_ebs_volume_size[local.environment]
      volume_type           = var.ucfs_server_stub_ebs_volume_type[local.environment]
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
  count              = local.deploy_ucfs_server_stub[local.environment] ? 1 : 0
  name               = "ucfs_server_stub"
  assume_role_policy = data.aws_iam_policy_document.ucfs_server_stub_assume_role[0].json
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
  role  = aws_iam_role.ucfs_server_stub[0].name
}

resource "aws_security_group" "ucfs_server_stub" {
  name        = "ucfs_server_stub"
  description = "Control access to and from UCFS export server stub"
  vpc_id      = data.terraform_remote_state.ingest.outputs.stub_ucfs_vpc.vpc.id

  tags = merge(
    local.common_tags,
    {
      "Name" = "ucfs_server_stub"
    }
  )
}

data "template_file" "ucfs_server_stub" {
  count = local.deploy_ucfs_server_stub[local.environment] ? 1 : 0
  template = file("ucfs_server_stub_userdata.tpl", {
    environment_name = local.environment
    //    truststore_aliases = local.ucfs_server_stub_truststore_aliases[local.environment]
    //    truststore_certs = local.ucfs_server_stub_truststore_certs[local.environment]
    //    private_key_alias = "ucfs-server-stub"
    internet_proxy                                   = data.terraform_remote_state.ingest.outputs.internet_proxy.host
    non_proxied_endpoints                            = join(",", data.terraform_remote_state.ingest.outputs.stub_ucfs_vpc.vpc.no_proxy_list)
    cwa_namespace                                    = local.cw_ucfs_server_stub_agent_namespace
    cwa_metrics_collection_interval                  = local.cw_agent_metrics_collection_interval
    cwa_cpu_metrics_collection_interval              = local.cw_agent_cpu_metrics_collection_interval
    cwa_disk_measurement_metrics_collection_interval = local.cw_agent_disk_measurement_metrics_collection_interval
    cwa_disk_io_metrics_collection_interval          = local.cw_agent_disk_io_metrics_collection_interval
    cwa_mem_metrics_collection_interval              = local.cw_agent_mem_metrics_collection_interval
    cwa_netstat_metrics_collection_interval          = local.cw_agent_netstat_metrics_collection_interval
    cwa_log_group_name                               = aws_cloudwatch_log_group.ucfs_server_stub_logs.name
    s3_artefact_bucket                               = data.terraform_remote_state.management_artefact.outputs.artefact_bucket.id
    s3_scripts_bucket                                = data.terraform_remote_state.common.outputs.config_bucket.id
    s3_file_ucfs_server_stub_logrotate               = aws_s3_bucket_object.ucfs_server_stub_logrotate_script.id
    s3_file_ucfs_server_stub_cloudwatch_sh           = aws_s3_bucket_object.ucfs_server_stub_cloudwatch_script.id
    ucfs_server_stub_release                         = var.ucfs_server_stub_release
  })
}

resource "aws_cloudwatch_log_group" "ucfs_server_stub_logs" {
  name              = "/app/${local.ucfs_server_stub_name}"
  retention_in_days = 180
  tags              = local.common_tags
}

data "local_file" "ucfs_server_stub_logrotate_script" {
  filename = "files/ucfs_server_stub.logrotate"
}

resource "aws_s3_bucket_object" "ucfs_server_stub_logrotate_script" {
  bucket     = data.terraform_remote_state.common.outputs.config_bucket.id
  key        = "component/ucfs-server-stub/ucfs-server-stub.logrotate"
  content    = data.local_file.ucfs_server_stub_logrotate_script.content
  kms_key_id = data.terraform_remote_state.common.outputs.config_bucket_cmk.arn

  tags = merge(
    local.common_tags,
    {
      Name = "ucfs-server-stub-logrotate-script"
    },
  )
}

data "local_file" "ucfs_server_stub_cloudwatch_script" {
  filename = "files/ucfs_server_stub_cloudwatch.sh"
}

resource "aws_s3_bucket_object" "ucfs_server_stub_cloudwatch_script" {
  bucket     = data.terraform_remote_state.common.outputs.config_bucket.id
  key        = "component/ucfs-server-stub/ucfs-server-stub-cloudwatch.sh"
  content    = data.local_file.ucfs_server_stub_cloudwatch_script.content
  kms_key_id = data.terraform_remote_state.common.outputs.config_bucket_cmk.arn

  tags = merge(
    local.common_tags,
    {
      Name = "ucfs-server-stub-cloudwatch-script"
    },
  )
}
