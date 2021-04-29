
output "zone_id" {
	description = "The dns zone id"
	value       = aws_route53_zone.dns.zone_id
}
	