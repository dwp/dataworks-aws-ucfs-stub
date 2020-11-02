output "export_server_asg" {
  value = {
    name = aws_autoscaling_group.stub_ucfs_export_server[0].name
  }
}
