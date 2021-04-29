
resource "aws_route53_zone" "dns" {
	name = var.domain_name
}
	