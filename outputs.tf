output "export_server_asg" {
  value = {
    name = local.deploy_stub_ucfs_export_server[local.environment] ? aws_autoscaling_group.stub_ucfs_export_server[0].name : "NA"
  }
}
