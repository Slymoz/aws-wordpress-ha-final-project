output "wordpress_alb_url" {
  description = "Public Application Load Balancer access URL for WordPress verification"
  value       = "http://${aws_lb.web.dns_name}/"
}

output "s3_media_bucket" {
  description = "Persistent metadata S3 asset container name"
  value       = aws_s3_bucket.media.id
}

output "rds_private_endpoint" {
  description = "Isolated internal relational storage host target address"
  value       = aws_db_instance.wordpress.address
}

output "asg_name" {
  description = "Identified elastic autoscaling worker pool group"
  value       = aws_autoscaling_group.web.name
}
