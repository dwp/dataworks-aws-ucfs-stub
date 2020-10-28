resource "aws_launch_template" "ucfs_server_stub" {
  count         = local.deploy_ucfs_server_stub[local.environment] ? 1 : 0
  name_prefix   = "ucfs_server_stub_"
  image_id      = var.al2_hardened_ami_id
  instance_type = var.ucfs_server_stub_ec2_instance_type[local.environment]
  vpc_security_group_ids = [
  aws_security_group.ucfs_server_stub[0].id]
  user_data = base64encode(templatefile("ucfs_server_stub_userdata.tpl", {
    environment_name                                 = local.environment
    acm_cert_arn                                     = aws_acm_certificate.ucfs_server_stub[0].arn
    truststore_aliases                               = local.ucfs_server_stub_truststore_aliases[local.environment]
    truststore_certs                                 = local.ucfs_server_stub_truststore_certs[local.environment]
    private_key_alias                                = "ucfs-server-stub"
    internet_proxy                                   = data.terraform_remote_state.ingest.outputs.internet_proxy.host
    non_proxied_endpoints                            = join(",", data.terraform_remote_state.ingest.outputs.stub_ucfs_vpc.no_proxy_list)
    cwa_namespace                                    = local.cw_ucfs_server_stub_agent_namespace
    cwa_metrics_collection_interval                  = local.cw_agent_metrics_collection_interval
    cwa_cpu_metrics_collection_interval              = local.cw_agent_cpu_metrics_collection_interval
    cwa_disk_measurement_metrics_collection_interval = local.cw_agent_disk_measurement_metrics_collection_interval
    cwa_disk_io_metrics_collection_interval          = local.cw_agent_disk_io_metrics_collection_interval
    cwa_mem_metrics_collection_interval              = local.cw_agent_mem_metrics_collection_interval
    cwa_netstat_metrics_collection_interval          = local.cw_agent_netstat_metrics_collection_interval
    cwa_log_group_name                               = aws_cloudwatch_log_group.ucfs_server_stub_logs[0].name
    s3_artefact_bucket                               = data.terraform_remote_state.ingest.outputs.s3_buckets.input_bucket
    s3_artefact_prefix                               = "business-data/tarballs-mongo/ucdata/"
    s3_scripts_bucket                                = data.terraform_remote_state.common.outputs.config_bucket.id
    s3_file_ucfs_server_stub_logrotate               = aws_s3_bucket_object.ucfs_server_stub_logrotate_script[0].id
    s3_file_ucfs_server_stub_cloudwatch_sh           = aws_s3_bucket_object.ucfs_server_stub_cloudwatch_script[0].id
    s3_file_ucfs_server_stub_post_tarballs_sh        = aws_s3_bucket_object.ucfs_server_stub_post_tarballs_script[0].id
  }))
  instance_initiated_shutdown_behavior = "terminate"

  iam_instance_profile {
    arn = aws_iam_instance_profile.ucfs_server_stub[0].arn
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

resource "aws_acm_certificate" "ucfs_server_stub" {
  count                     = local.deploy_ucfs_server_stub[local.environment] ? 1 : 0
  certificate_authority_arn = data.terraform_remote_state.certificate_authority.outputs.root_ca.arn
  domain_name               = "${local.ucfs_server_stub_name}.${local.env_prefix[local.environment]}dataworks.dwp.gov.uk"

  tags = merge(
    local.common_tags,
    {
      Name = "ucfs-server-stub"
    },
  )
}

resource "aws_iam_role" "ucfs_server_stub" {
  count              = local.deploy_ucfs_server_stub[local.environment] ? 1 : 0
  name               = "ucfs_server_stub"
  assume_role_policy = data.aws_iam_policy_document.ucfs_server_stub_assume_role[0].json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "amazon_ssm_managed_instance_core" {
  role       = aws_iam_role.ucfs_server_stub[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "tarball_ingester_cwasp" {
  role       = aws_iam_role.ucfs_server_stub[0].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "ucfs_server_stub_ssm_logs" {
  role       = aws_iam_role.ucfs_server_stub[0].name
  policy_arn = aws_iam_policy.ucfs_stub_server_ssm_logs.arn
}

data "aws_iam_policy_document" "ucfs_server_stub_ssm_logs" {
  statement {
    effect = "Allow"
    actions = [
      "logs:DescribeLogGroups",
    ]
    resources = [
      "arn:aws:logs:${var.region}:${local.account[local.environment]}:log-group::log-stream:*"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = [
      "arn:aws:logs:${var.region}:${local.account[local.environment]}:log-group:/aws/ssm/session_manager:log-stream:*",
    ]
  }
}

resource "aws_iam_policy" "ucfs_stub_server_ssm_logs" {
  name        = "UCFSServerStubSSMLogs"
  description = "Allow SSM session logging"
  policy      = data.aws_iam_policy_document.ucfs_server_stub_ssm_logs.json
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
  count       = local.deploy_ucfs_server_stub[local.environment] ? 1 : 0
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
  count       = local.deploy_ucfs_server_stub[local.environment] ? 1 : 0
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
  count                    = local.deploy_ucfs_server_stub[local.environment] ? 1 : 0
  description              = "Allow UCFS server stub access to Internet Proxy (for ACM-PCA)"
  type                     = "egress"
  source_security_group_id = data.terraform_remote_state.ingest.outputs.internet_proxy.sg
  protocol                 = "tcp"
  from_port                = 3128
  to_port                  = 3128
  security_group_id        = aws_security_group.ucfs_server_stub[0].id
}

resource "aws_security_group_rule" "ingress_ucfs_server_stub_to_internet" {
  count                    = local.deploy_ucfs_server_stub[local.environment] ? 1 : 0
  description              = "Allow UCFS server stub access to Internet Proxy (for ACM-PCA)"
  type                     = "ingress"
  source_security_group_id = aws_security_group.ucfs_server_stub[0].id
  protocol                 = "tcp"
  from_port                = 3128
  to_port                  = 3128
  security_group_id        = data.terraform_remote_state.ingest.outputs.internet_proxy.sg
}

resource "aws_security_group_rule" "egress_ucfs_server_stub_to_vpc_endpoint" {
  count                    = local.deploy_ucfs_server_stub[local.environment] ? 1 : 0
  description              = "Allow UCFS server stub access to VPC endpoint"
  type                     = "egress"
  source_security_group_id = data.terraform_remote_state.ingest.outputs.stub_ucfs_interface_vpce_sg.id
  protocol                 = "tcp"
  from_port                = 443
  to_port                  = 443
  security_group_id        = aws_security_group.ucfs_server_stub[0].id
}

resource "aws_security_group_rule" "ingress_ucfs_server_stub_to_vpc_endpoint" {
  count                    = local.deploy_ucfs_server_stub[local.environment] ? 1 : 0
  description              = "Allow UCFS server stub access to VPC endpoint"
  type                     = "ingress"
  source_security_group_id = aws_security_group.ucfs_server_stub[0].id
  protocol                 = "tcp"
  from_port                = 443
  to_port                  = 443
  security_group_id        = data.terraform_remote_state.ingest.outputs.stub_ucfs_interface_vpce_sg.id
}


data "aws_iam_policy_document" "ucfs_server_stub" {
  statement {
    sid    = "AllowACM"
    effect = "Allow"

    actions = [
      "acm:*Certificate",
    ]

    resources = [
    aws_acm_certificate.ucfs_server_stub[0].arn]
  }

  statement {
    sid    = "GetPublicCerts"
    effect = "Allow"

    actions = [
      "s3:GetObject",
    ]

    resources = [
    data.terraform_remote_state.certificate_authority.outputs.public_cert_bucket.arn]
  }

  statement {
    sid    = "AllowUseDefaultEbsCmk"
    effect = "Allow"

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]


    resources = [
    data.terraform_remote_state.security-tools.outputs.ebs_cmk.arn]
  }

  statement {
    effect = "Allow"
    sid    = "AllowAccessToConfigBucket"

    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]


    resources = [
    data.terraform_remote_state.common.outputs.config_bucket.arn]
  }

  statement {
    effect = "Allow"
    sid    = "AllowAccessToConfigBucketObjects"

    actions = [
    "s3:GetObject"]

    resources = [
    "${data.terraform_remote_state.common.outputs.config_bucket.arn}/*"]
  }

  statement {
    sid    = "AllowKMSDecryptionOfS3ConfigBucketObj"
    effect = "Allow"

    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
    ]

    resources = [
    data.terraform_remote_state.common.outputs.config_bucket_cmk.arn]
  }

  statement {
    sid    = "AllowDescribeASGToCheckLaunchTemplate"
    effect = "Allow"
    actions = [
    "autoscaling:DescribeAutoScalingGroups"]
    resources = [
    "*"]
  }

  statement {
    sid    = "AllowDescribeEC2LaunchTemplatesToCheckLatestVersion"
    effect = "Allow"
    actions = [
    "ec2:DescribeLaunchTemplates"]
    resources = [
    "*"]
  }

  statement {
    sid    = "UCFSStubKMS"
    effect = "Allow"

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]

    resources = [
      data.terraform_remote_state.ingest.outputs.input_bucket_cmk.arn
    ]
  }

  statement {
    sid    = "AllowAccessToArtefactBucket"
    effect = "Allow"
    actions = [
    "s3:GetBucketLocation"]

    resources = [
    data.terraform_remote_state.management_artefact.outputs.artefact_bucket.arn]
  }

  statement {
    sid    = "AllowPullFromArtefactBucket"
    effect = "Allow"
    actions = [
    "s3:GetObject"]
    resources = [
    "${data.terraform_remote_state.management_artefact.outputs.artefact_bucket.arn}/*"]
  }

  statement {
    sid    = "AllowDecryptArtefactBucket"
    effect = "Allow"

    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
    ]

    resources = [
    data.terraform_remote_state.management_artefact.outputs.artefact_bucket.cmk_arn]
  }

  statement {
    sid    = "AllowUCFSStubToAccessLogGroups"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams"
    ]
    resources = [
    aws_cloudwatch_log_group.ucfs_server_stub_logs[0].arn]
  }
}

resource "aws_autoscaling_group" "ucfs_server_stub" {
  count                     = local.deploy_ucfs_server_stub[local.environment] ? 1 : 0
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

  //  tags = [
  //    for key, value in local.ucfs_server_stub_tags_asg :
  //    {
  //      key                 = key
  //      value               = value
  //      propagate_at_launch = true
  //    }
  //  ]

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
    desired_capacity]
  }
}

resource "aws_cloudwatch_log_group" "ucfs_server_stub_logs" {
  count             = local.deploy_ucfs_server_stub[local.environment] ? 1 : 0
  name              = "/app/${local.ucfs_server_stub_name}"
  retention_in_days = 180
  tags              = local.common_tags
}

data "local_file" "ucfs_server_stub_logrotate_script" {
  filename = "files/ucfs_server_stub.logrotate"
}

resource "aws_s3_bucket_object" "ucfs_server_stub_logrotate_script" {
  count      = local.deploy_ucfs_server_stub[local.environment] ? 1 : 0
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
  count      = local.deploy_ucfs_server_stub[local.environment] ? 1 : 0
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
  count      = local.deploy_ucfs_server_stub[local.environment] ? 1 : 0
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
