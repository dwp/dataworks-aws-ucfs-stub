resource "aws_launch_template" "ucfs_stub" {
  name_prefix   = "ucfs_stub_"
  image_id      = var.al2_hardened_ami_id
  instance_type = var.ucfs_stub_ec2_instance_type[local.environment]

}

//resource "aws_security_group" "ucfs_stub" {
//  name = "ucfs_stub"
//  description = "Control access to and from UCFS export server stub"
//  vpc_id = ""
//}