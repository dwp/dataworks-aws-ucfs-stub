resource "aws_launch_template" "ucfs_server_stub" {
  count         = local.deploy_stub_ucfs_export_server[local.environment] ? 1 : 0
  name_prefix   = "ucfs_server_stub_"
  image_id      = var.al2_hardened_ami_id
  instance_type = var.ucfs_server_stub_ec2_instance_type[local.environment]
  vpc_security_group_ids = [
  aws_security_group.ucfs_server_stub[0].id]
  user_data = base64encode(templatefile("ucfs_server_stub_userdata.tpl", {
    environment_name                                 = local.environment
    acm_cert_arn                                     = aws_acm_certificate.stub_ucfs_export_server[0].arn
    truststore_aliases                               = local.ucfs_server_stub_truststore_aliases[local.environment]
    truststore_certs                                 = local.ucfs_server_stub_truststore_certs[local.environment]
    private_key_alias                                = "ucfs-server-stub"
    internet_proxy                                   = data.terraform_remote_state.ingest.outputs.stub_internet_proxy.host
    non_proxied_endpoints                            = join(",", data.terraform_remote_state.ingest.outputs.stub_ucfs_vpc.no_proxy_list)
    cwa_namespace                                    = local.cw_ucfs_server_stub_agent_namespace
    cwa_metrics_collection_interval                  = local.cw_agent_metrics_collection_interval
    cwa_cpu_metrics_collection_interval              = local.cw_agent_cpu_metrics_collection_interval
    cwa_disk_measurement_metrics_collection_interval = local.cw_agent_disk_measurement_metrics_collection_interval
    cwa_disk_io_metrics_collection_interval          = local.cw_agent_disk_io_metrics_collection_interval
    cwa_mem_metrics_collection_interval              = local.cw_agent_mem_metrics_collection_interval
    cwa_netstat_metrics_collection_interval          = local.cw_agent_netstat_metrics_collection_interval
    cwa_log_group_name                               = aws_cloudwatch_log_group.ucfs_server_stub_logs[0].name
    s3_input_bucket                                  = data.terraform_remote_state.ingest.outputs.s3_buckets.input_bucket
    s3_input_prefix                                  = "business-data/tarballs-mongo/ucdata/"
    s3_scripts_bucket                                = data.terraform_remote_state.common.outputs.config_bucket.id
    s3_file_ucfs_server_stub_logrotate               = aws_s3_bucket_object.ucfs_server_stub_logrotate_script[0].id
    s3_file_ucfs_server_stub_cloudwatch_sh           = aws_s3_bucket_object.ucfs_server_stub_cloudwatch_script[0].id
    s3_file_ucfs_server_stub_post_tarballs_sh        = aws_s3_bucket_object.ucfs_server_stub_post_tarballs_script[0].id
  }))
  instance_initiated_shutdown_behavior = "terminate"

  iam_instance_profile {
    arn = aws_iam_instance_profile.stub_ucfs_export_server[0].arn
  }

  block_device_mappings {
    device_name = "/dev/xvdf"

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
        SSMEnabled  = local.ucfs_server_stub_ssmenabled[local.environment]
      }
    )
  }

}


resource "aws_acm_certificate" "stub_ucfs_export_server" {
  count                     = local.deploy_stub_ucfs_export_server[local.environment] ? 1 : 0
  certificate_authority_arn = data.terraform_remote_state.certificate_authority.outputs.root_ca.arn
  domain_name               = "${local.stub_ucfs_export_server_name}.${local.env_prefix[local.environment]}dataworks.dwp.gov.uk"

  tags = merge(
    local.common_tags,
    {
      Name = "stub-ucfs-export-server"
    },
  )
}

data "aws_iam_policy_document" "stub_ucfs_export_server_assume_role" {
  statement {
    sid = "EC2AssumeRole"
    principals {
      identifiers = ["ec2.amazonaws.com"]
      type        = "Service"
    }
    actions = [
      "sts:AssumeRole"
    ]
  }
}

resource "aws_iam_role" "stub_ucfs_export_server" {
  count              = local.deploy_stub_ucfs_export_server[local.environment] ? 1 : 0
  name               = "StubUCFSExportServer"
  assume_role_policy = data.aws_iam_policy_document.stub_ucfs_export_server_assume_role.json
  tags               = local.common_tags
}

resource "aws_iam_instance_profile" "stub_ucfs_export_server" {
  count = local.deploy_stub_ucfs_export_server[local.environment] ? 1 : 0
  name  = "StubUCFSExportServer"
  role  = aws_iam_role.stub_ucfs_export_server[0].name
}

resource "aws_iam_role_policy_attachment" "stub_ucfs_export_server_amazon_ssm_managed_instance_core" {
  count      = local.deploy_stub_ucfs_export_server[local.environment] ? 1 : 0
  role       = aws_iam_role.stub_ucfs_export_server[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "stub_ucfs_export_server_cloudwatch_agent_server_policy" {
  count      = local.deploy_stub_ucfs_export_server[local.environment] ? 1 : 0
  role       = aws_iam_role.stub_ucfs_export_server[0].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Allows the instance to describe ASG & Launch Template for termination handling
resource "aws_iam_role_policy_attachment" "stub_ucfs_export_server_amazon_ec2_readonly_access" {
  count      = local.deploy_stub_ucfs_export_server[local.environment] ? 1 : 0
  role       = aws_iam_role.stub_ucfs_export_server[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "stub_ucfs_export_server_export_certificate_bucket_read" {
  count      = local.deploy_stub_ucfs_export_server[local.environment] ? 1 : 0
  role       = aws_iam_role.stub_ucfs_export_server[0].name
  policy_arn = "arn:aws:iam::${local.account[local.environment]}:policy/CertificateBucketRead"
}

resource "aws_iam_role_policy_attachment" "stub_ucfs_export_server_config_bucket_read" {
  count      = local.deploy_stub_ucfs_export_server[local.environment] ? 1 : 0
  role       = aws_iam_role.stub_ucfs_export_server[0].name
  policy_arn = "arn:aws:iam::${local.account[local.environment]}:policy/ConfigBucketRead"
}

resource "aws_iam_role_policy_attachment" "stub_ucfs_export_server_ebs_cmk_instance_encrypt_decrypt" {
  count      = local.deploy_stub_ucfs_export_server[local.environment] ? 1 : 0
  role       = aws_iam_role.stub_ucfs_export_server[0].name
  policy_arn = "arn:aws:iam::${local.account[local.environment]}:policy/EBSCMKInstanceEncryptDecrypt"
}

data "aws_iam_policy_document" "stub_ucfs_export_server" {
  statement {
    sid    = "CertificateExport"
    effect = "Allow"
    actions = [
      "acm:ExportCertificate",
    ]
    resources = [aws_acm_certificate.stub_ucfs_export_server[0].arn]
  }

  statement {
    sid    = "InputBucketKMSDecrypt"
    effect = "Allow"

    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
    ]

    resources = [
      data.terraform_remote_state.ingest.outputs.input_bucket_cmk.arn
    ]
  }

  statement {
    sid    = "InputBucketRead"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]

    resources = [
    data.terraform_remote_state.ingest.outputs.s3_input_bucket_arn.input_bucket]
  }

  statement {
    sid    = "SyntheticTarballsRead"
    effect = "Allow"
    actions = [
      "s3:GetObject"
    ]
    resources = [
      "${data.terraform_remote_state.ingest.outputs.s3_input_bucket_arn.input_bucket}/business-data/tarballs-mongo/ucdata/*"
    ]
  }

  statement {
    sid    = "CloudWatchLogsWrite"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams"
    ]
    resources = [
      aws_cloudwatch_log_group.ucfs_server_stub_logs[0].arn
    ]
  }
}

resource "aws_iam_policy" "stub_ucfs_export_server" {
  count       = local.deploy_stub_ucfs_export_server[local.environment] ? 1 : 0
  name        = "StubUCFSExportServer"
  description = "Custom policy for Stub UCFS Export Server"
  policy      = data.aws_iam_policy_document.stub_ucfs_export_server.json
}

resource "aws_iam_role_policy_attachment" "stub_ucfs_export_server" {
  count      = local.deploy_stub_ucfs_export_server[local.environment] ? 1 : 0
  role       = aws_iam_role.stub_ucfs_export_server[0].name
  policy_arn = aws_iam_policy.stub_ucfs_export_server[0].arn
}

resource "aws_security_group" "ucfs_server_stub" {
  count       = local.deploy_stub_ucfs_export_server[local.environment] ? 1 : 0
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

resource "aws_security_group_rule" "ucfs_server_stub_to_s3" {
  count       = local.deploy_stub_ucfs_export_server[local.environment] ? 1 : 0
  description = "Allow UCFS server stub to reach S3"
  type        = "egress"
  prefix_list_ids = [
  data.terraform_remote_state.ingest.outputs.stub_ucfs_vpc.prefix_list_ids.s3]
  protocol          = "tcp"
  from_port         = 443
  to_port           = 443
  security_group_id = aws_security_group.ucfs_server_stub[0].id
}

resource "aws_security_group_rule" "egress_ucfs_server_stub_to_internet" {
  count                    = local.deploy_stub_ucfs_export_server[local.environment] ? 1 : 0
  description              = "Allow UCFS server stub access to Internet Proxy (for ACM-PCA)"
  type                     = "egress"
  source_security_group_id = data.terraform_remote_state.ingest.outputs.stub_internet_proxy.sg
  protocol                 = "tcp"
  from_port                = 3128
  to_port                  = 3128
  security_group_id        = aws_security_group.ucfs_server_stub[0].id
}

resource "aws_security_group_rule" "ingress_ucfs_server_stub_to_internet" {
  count                    = local.deploy_stub_ucfs_export_server[local.environment] ? 1 : 0
  description              = "Allow UCFS server stub access to Internet Proxy (for ACM-PCA)"
  type                     = "ingress"
  source_security_group_id = aws_security_group.ucfs_server_stub[0].id
  protocol                 = "tcp"
  from_port                = 3128
  to_port                  = 3128
  security_group_id        = data.terraform_remote_state.ingest.outputs.stub_internet_proxy.sg
}

resource "aws_security_group_rule" "egress_ucfs_server_stub_to_vpc_endpoint" {
  count                    = local.deploy_stub_ucfs_export_server[local.environment] ? 1 : 0
  description              = "Allow UCFS server stub access to VPC endpoint"
  type                     = "egress"
  source_security_group_id = data.terraform_remote_state.ingest.outputs.stub_ucfs_interface_vpce_sg.id
  protocol                 = "tcp"
  from_port                = 443
  to_port                  = 443
  security_group_id        = aws_security_group.ucfs_server_stub[0].id
}

resource "aws_security_group_rule" "ingress_ucfs_server_stub_to_vpc_endpoint" {
  count                    = local.deploy_stub_ucfs_export_server[local.environment] ? 1 : 0
  description              = "Allow access to VPC endpoint from UCFS server stub"
  type                     = "ingress"
  source_security_group_id = aws_security_group.ucfs_server_stub[0].id
  protocol                 = "tcp"
  from_port                = 443
  to_port                  = 443
  security_group_id        = data.terraform_remote_state.ingest.outputs.stub_ucfs_interface_vpce_sg.id
}

resource "aws_autoscaling_group" "ucfs_server_stub" {
  count                     = local.deploy_stub_ucfs_export_server[local.environment] ? 1 : 0
  name_prefix               = "${aws_launch_template.ucfs_server_stub[0].name}-lt_ver${aws_launch_template.ucfs_server_stub[0].latest_version}_"
  min_size                  = local.ucfs_server_stub_asg_min[local.environment]
  desired_capacity          = local.ucfs_server_stub_asg_desired[local.environment]
  max_size                  = local.ucfs_server_stub_asg_max[local.environment]
  health_check_grace_period = 600
  health_check_type         = "EC2"
  force_delete              = true
  vpc_zone_identifier       = data.terraform_remote_state.ingest.outputs.stub_ucfs_subnets.id[0]

  launch_template {
    id      = aws_launch_template.ucfs_server_stub[0].id
    version = "$Latest"
  }

  dynamic "tag" {
    for_each = local.ucfs_server_stub_tags_asg

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
    desired_capacity]
  }
}

resource "aws_cloudwatch_log_group" "ucfs_server_stub_logs" {
  count             = local.deploy_stub_ucfs_export_server[local.environment] ? 1 : 0
  name              = "/app/${local.stub_ucfs_export_server_name}"
  retention_in_days = 180
  tags              = local.common_tags
}

data "local_file" "ucfs_server_stub_logrotate_script" {
  filename = "files/ucfs_server_stub.logrotate"
}

resource "aws_s3_bucket_object" "ucfs_server_stub_logrotate_script" {
  count      = local.deploy_stub_ucfs_export_server[local.environment] ? 1 : 0
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
  count      = local.deploy_stub_ucfs_export_server[local.environment] ? 1 : 0
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

data "local_file" "ucfs_server_stub_post_tarballs_script" {
  filename = "files/post_tarballs.sh"
}

resource "aws_s3_bucket_object" "ucfs_server_stub_post_tarballs_script" {
  count      = local.deploy_stub_ucfs_export_server[local.environment] ? 1 : 0
  bucket     = data.terraform_remote_state.common.outputs.config_bucket.id
  key        = "component/ucfs-server-stub/post_tarballs.sh"
  content    = data.local_file.ucfs_server_stub_post_tarballs_script.content
  kms_key_id = data.terraform_remote_state.common.outputs.config_bucket_cmk.arn

  tags = merge(
    local.common_tags,
    {
      Name = "ucfs-server-stub-post-tarballs-script"
    },
  )
}
