resource "aws_vpc_endpoint_service" "tarball_ingester_replacement" {
  acceptance_required           = true
  network_load_balancer_arns    = [ aws_lb.tarball_ingester_replacement.arn ]
  tags                          = local.common_tags
}

resource "aws_vpc_endpoint_service_allowed_principal" "tarball_ingester_replacement" {
  count                     = local.tarball_ingester_uc_replacement_connected[local.environment] ? 1 : 0   
  vpc_endpoint_service_id   = aws_vpc_endpoint_service.tarball_ingester_replacement.id
  principal_arn             = format("arn:aws:iam::%s:root", local.account[local.environment])
}
