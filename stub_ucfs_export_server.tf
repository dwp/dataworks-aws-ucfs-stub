resource "aws_vpc_endpoint" "tarball_ingester" {
  vpc_id             = data.terraform_remote_state.ingest.outputs.stub_ucfs_vpc.vpc.id
  service_name       = data.terraform_remote_state.tarball_ingester.outputs.tarball_ingester_endpoint.service_name
  security_group_ids = [data.terraform_remote_state.ingest.outputs.stub_ucfs_interface_vpce_sg.id]
  vpc_endpoint_type  = "Interface"
}

resource "aws_vpc_endpoint_subnet_association" "tarball_ingester" {
  count           = length(data.terraform_remote_state.ingest.outputs.stub_ucfs_subnets.id)
  vpc_endpoint_id = aws_vpc_endpoint.tarball_ingester.id
  subnet_id       = element(data.terraform_remote_state.ingest.outputs.stub_ucfs_subnets.id, count.index)
}

resource "aws_route53_record" "tarball_ingester" {
  provider = aws.management_dns
  zone_id  = data.terraform_remote_state.management_dns.outputs.dataworks_zone.id
  name     = data.terraform_remote_state.tarball_ingester.outputs.tarball_ingester_fqdn
  type     = "CNAME"
  ttl      = "60"
  records  = [aws_vpc_endpoint.tarball_ingester.dns_entry[0].dns_name]
}

resource "aws_launch_template" "stub_ucfs_export_server" {
  count         = local.deploy_stub_ucfs_export_server[local.environment] ? 1 : 0
  name_prefix   = "stub_ucfs_export_server_"
  image_id      = var.al2_hardened_ami_id
  instance_type = var.stub_ucfs_export_server_ec2_instance_type[local.environment]
  vpc_security_group_ids = [
  aws_security_group.stub_ucfs_export_server[0].id]
  user_data = base64encode(templatefile("files/stub_ucfs_export_server_userdata.tpl", {
    environment_name                                     = local.environment
    acm_cert_arn                                         = aws_acm_certificate.stub_ucfs_export_server[0].arn
    truststore_aliases                                   = local.stub_ucfs_export_server_truststore_aliases[local.environment]
    truststore_certs                                     = local.stub_ucfs_export_server_truststore_certs[local.environment]
    private_key_alias                                    = "ucfs-server-stub"
    internet_proxy                                       = data.terraform_remote_state.ingest.outputs.stub_internet_proxy.host
    non_proxied_endpoints                                = join(",", data.terraform_remote_state.ingest.outputs.stub_ucfs_vpc.no_proxy_list)
    cwa_namespace                                        = local.cw_stub_ucfs_export_server_agent_namespace
    cwa_metrics_collection_interval                      = local.cw_agent_metrics_collection_interval
    cwa_cpu_metrics_collection_interval                  = local.cw_agent_cpu_metrics_collection_interval
    cwa_disk_measurement_metrics_collection_interval     = local.cw_agent_disk_measurement_metrics_collection_interval
    cwa_disk_io_metrics_collection_interval              = local.cw_agent_disk_io_metrics_collection_interval
    cwa_mem_metrics_collection_interval                  = local.cw_agent_mem_metrics_collection_interval
    cwa_netstat_metrics_collection_interval              = local.cw_agent_netstat_metrics_collection_interval
    cwa_log_group_name                                   = aws_cloudwatch_log_group.stub_ucfs_export_server_logs[0].name
    s3_scripts_bucket                                    = data.terraform_remote_state.common.outputs.config_bucket.id
    s3_file_stub_ucfs_export_server_logrotate            = aws_s3_bucket_object.stub_ucfs_export_server_logrotate_script[0].id
    s3_file_stub_ucfs_export_server_logrotate_md5        = md5(data.local_file.stub_ucfs_export_server_logrotate_script.content)
    s3_file_stub_ucfs_export_server_cloudwatch_sh        = aws_s3_bucket_object.stub_ucfs_export_server_cloudwatch_script[0].id
    s3_file_stub_ucfs_export_server_cloudwatch_sh_md5    = md5(data.local_file.stub_ucfs_export_server_cloudwatch_script.content)
    s3_file_stub_ucfs_export_server_post_tarballs_sh     = aws_s3_bucket_object.stub_ucfs_export_server_post_tarballs_script[0].id
    s3_file_stub_ucfs_export_server_post_tarballs_sh_md5 = md5(aws_s3_bucket_object.stub_ucfs_export_server_post_tarballs_script[0].content)
  }))
  instance_initiated_shutdown_behavior = "terminate"

  iam_instance_profile {
    arn = aws_iam_instance_profile.stub_ucfs_export_server[0].arn
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.stub_ucfs_export_server_ebs_volume_size[local.environment]
      volume_type           = var.stub_ucfs_export_server_ebs_volume_type[local.environment]
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
      Name = "stub_ucfs_export_server"
    }
  )

  tag_specifications {
    resource_type = "instance"

    tags = merge(
      local.common_tags,
      {
        Name         = "stub_ucfs_export_server"
        Application  = "stub_ucfs_export_server"
        Persistence  = "Ignore"
        AutoShutdown = "False"
        SSMEnabled   = local.stub_ucfs_export_server_ssmenabled[local.environment]
      }
    )
  }

}


resource "aws_acm_certificate" "stub_ucfs_export_server" {
  count                     = local.deploy_stub_ucfs_export_server[local.environment] ? 1 : 0
  certificate_authority_arn = data.terraform_remote_state.certificate_authority.outputs.root_ca.arn
  domain_name               = "${local.stub_ucfs_export_server_name}.${local.env_prefix[local.environment]}dataworks.dwp.gov.uk"

  options {
    certificate_transparency_logging_preference = "ENABLED"
  }

  tags = merge(
    local.common_tags,
    {
      Name = local.stub_ucfs_export_server_name
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
  policy_arn = "arn:aws:iam::${local.account[local.environment]}:policy/CertificatesBucketRead"
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

resource "aws_iam_role_policy_attachment" "stub_ucfs_export_server_secrets_manager" {
  count      = local.deploy_stub_ucfs_export_server[local.environment] ? 1 : 0
  role       = aws_iam_role.stub_ucfs_export_server[0].name
  policy_arn = "arn:aws:iam::${local.account[local.environment]}:policy/MiniIOSecretsManager"
}

data "aws_iam_policy_document" "stub_ucfs_export_server" {
  count = local.deploy_stub_ucfs_export_server[local.environment] ? 1 : 0
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
      aws_cloudwatch_log_group.stub_ucfs_export_server_logs[0].arn
    ]
  }
}

resource "aws_iam_policy" "stub_ucfs_export_server" {
  count       = local.deploy_stub_ucfs_export_server[local.environment] ? 1 : 0
  name        = "StubUCFSExportServer"
  description = "Custom policy for Stub UCFS Export Server"
  policy      = data.aws_iam_policy_document.stub_ucfs_export_server[0].json
}

resource "aws_iam_role_policy_attachment" "stub_ucfs_export_server" {
  count      = local.deploy_stub_ucfs_export_server[local.environment] ? 1 : 0
  role       = aws_iam_role.stub_ucfs_export_server[0].name
  policy_arn = aws_iam_policy.stub_ucfs_export_server[0].arn
}

resource "aws_security_group" "stub_ucfs_export_server" {
  count       = local.deploy_stub_ucfs_export_server[local.environment] ? 1 : 0
  name        = "stub_ucfs_export_server"
  description = "Control access to and from stub UCFS export server"
  vpc_id      = data.terraform_remote_state.ingest.outputs.stub_ucfs_vpc.vpc.id

  tags = merge(
    local.common_tags,
    {
      "Name" = local.stub_ucfs_export_server_name
    }
  )
}

resource "aws_security_group_rule" "stub_ucfs_export_server_s3" {
  count             = local.deploy_stub_ucfs_export_server[local.environment] ? 1 : 0
  description       = "Allow stub UCFS export server to reach S3"
  type              = "egress"
  prefix_list_ids   = [data.terraform_remote_state.ingest.outputs.stub_ucfs_vpc.prefix_list_ids.s3]
  protocol          = "tcp"
  from_port         = 443
  to_port           = 443
  security_group_id = aws_security_group.stub_ucfs_export_server[0].id
}

resource "aws_security_group_rule" "stub_ucfs_export_server_s3_yum" {
  count             = local.deploy_stub_ucfs_export_server[local.environment] ? 1 : 0
  description       = "Allow stub UCFS export server to reach S3 for YUM"
  type              = "egress"
  prefix_list_ids   = [data.terraform_remote_state.ingest.outputs.stub_ucfs_vpc.prefix_list_ids.s3]
  protocol          = "tcp"
  from_port         = 80
  to_port           = 80
  security_group_id = aws_security_group.stub_ucfs_export_server[0].id
}

resource "aws_security_group_rule" "egress_stub_ucfs_export_server_internet" {
  count                    = local.deploy_stub_ucfs_export_server[local.environment] ? 1 : 0
  description              = "Allow stub UCFS export server access to Internet Proxy (for ACM-PCA)"
  type                     = "egress"
  source_security_group_id = data.terraform_remote_state.ingest.outputs.stub_internet_proxy.sg
  protocol                 = "tcp"
  from_port                = 3128
  to_port                  = 3128
  security_group_id        = aws_security_group.stub_ucfs_export_server[0].id
}

resource "aws_security_group_rule" "ingress_stub_ucfs_export_server_internet" {
  count                    = local.deploy_stub_ucfs_export_server[local.environment] ? 1 : 0
  description              = "Allow stub UCFS export server access to Internet Proxy (for ACM-PCA)"
  type                     = "ingress"
  source_security_group_id = aws_security_group.stub_ucfs_export_server[0].id
  protocol                 = "tcp"
  from_port                = 3128
  to_port                  = 3128
  security_group_id        = data.terraform_remote_state.ingest.outputs.stub_internet_proxy.sg
}

resource "aws_security_group_rule" "egress_stub_ucfs_export_server_vpc_endpoint" {
  count                    = local.deploy_stub_ucfs_export_server[local.environment] ? 1 : 0
  description              = "Allow stub UCFS export server access to VPC endpoints"
  type                     = "egress"
  source_security_group_id = data.terraform_remote_state.ingest.outputs.stub_ucfs_interface_vpce_sg.id
  protocol                 = "tcp"
  from_port                = 443
  to_port                  = 443
  security_group_id        = aws_security_group.stub_ucfs_export_server[0].id
}

resource "aws_security_group_rule" "ingress_stub_ucfs_export_server_vpc_endpoint" {
  count                    = local.deploy_stub_ucfs_export_server[local.environment] ? 1 : 0
  description              = "Allow stub UCFS export server access to VPC endpoints"
  type                     = "ingress"
  source_security_group_id = aws_security_group.stub_ucfs_export_server[0].id
  protocol                 = "tcp"
  from_port                = 443
  to_port                  = 443
  security_group_id        = data.terraform_remote_state.ingest.outputs.stub_ucfs_interface_vpce_sg.id
}

resource "aws_autoscaling_group" "stub_ucfs_export_server" {
  count                     = local.deploy_stub_ucfs_export_server[local.environment] ? 1 : 0
  name_prefix               = "${aws_launch_template.stub_ucfs_export_server[0].name}-lt_ver${aws_launch_template.stub_ucfs_export_server[0].latest_version}_"
  min_size                  = local.stub_ucfs_export_server_asg_min[local.environment]
  desired_capacity          = local.stub_ucfs_export_server_asg_desired[local.environment]
  max_size                  = local.stub_ucfs_export_server_asg_max[local.environment]
  health_check_grace_period = 600
  health_check_type         = "EC2"
  force_delete              = true
  vpc_zone_identifier       = data.terraform_remote_state.ingest.outputs.stub_ucfs_subnets.id

  launch_template {
    id      = aws_launch_template.stub_ucfs_export_server[0].id
    version = "$Latest"
  }

  dynamic "tag" {
    for_each = local.stub_ucfs_export_server_tags_asg

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [desired_capacity]
  }
}

resource "aws_cloudwatch_log_group" "stub_ucfs_export_server_logs" {
  count             = local.deploy_stub_ucfs_export_server[local.environment] ? 1 : 0
  name              = "/app/${local.stub_ucfs_export_server_name}"
  retention_in_days = 180
  tags              = local.common_tags
}

data "local_file" "stub_ucfs_export_server_logrotate_script" {
  filename = "files/stub_ucfs_export_server.logrotate"
}

resource "aws_s3_bucket_object" "stub_ucfs_export_server_logrotate_script" {
  count   = local.deploy_stub_ucfs_export_server[local.environment] ? 1 : 0
  bucket  = data.terraform_remote_state.common.outputs.config_bucket.id
  key     = "component/stub-ucfs-export-server/ucfs-server-stub.logrotate"
  content = data.local_file.stub_ucfs_export_server_logrotate_script.content

  tags = merge(
    local.common_tags,
    {
      Name = "stub-ucfs-export-server-logrotate-script"
    },
  )
}

data "local_file" "stub_ucfs_export_server_cloudwatch_script" {
  filename = "files/stub_ucfs_export_server_cloudwatch.sh"
}

resource "aws_s3_bucket_object" "stub_ucfs_export_server_cloudwatch_script" {
  count   = local.deploy_stub_ucfs_export_server[local.environment] ? 1 : 0
  bucket  = data.terraform_remote_state.common.outputs.config_bucket.id
  key     = "component/stub-ucfs-export-server/stub-ucfs-export-server-cloudwatch.sh"
  content = data.local_file.stub_ucfs_export_server_cloudwatch_script.content

  tags = merge(
    local.common_tags,
    {
      Name = "stub-ucfs-export-server-cloudwatch-script"
    },
  )
}

resource "aws_s3_bucket_object" "stub_ucfs_export_server_post_tarballs_script" {
  count  = local.deploy_stub_ucfs_export_server[local.environment] ? 1 : 0
  bucket = data.terraform_remote_state.common.outputs.config_bucket.id
  key    = "component/stub-ucfs-export-server/post_tarballs.sh"

  content = templatefile("files/post_tarballs.sh", {
    s3_input_bucket              = data.terraform_remote_state.ingest.outputs.s3_buckets.input_bucket
    s3_input_prefix              = "business-data/tarballs-mongo/ucdata/"
    tarball_ingester_s3_endpoint = data.terraform_remote_state.tarball_ingester.outputs.tarball_ingester_fqdn
    tarball_ingester_s3_bucket   = data.terraform_remote_state.tarball_ingester.outputs.tarball_ingester_minio_s3_bucket_name
  })

  tags = merge(
    local.common_tags,
    {
      Name = "stub-ucfs-export-server-post-tarballs-script"
    },
  )
}
