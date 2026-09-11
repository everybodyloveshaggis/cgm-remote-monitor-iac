output "elastic_ip" {
  description = "Elastic IP address of the Nightscout instance"
  value       = aws_eip.nightscout.public_ip
}

output "public_dns" {
  description = "AWS public DNS hostname"
  value       = aws_eip.nightscout.public_dns
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.nightscout.id
}

output "ssm_start_session_command" {
  description = "AWS CLI command to open a shell without exposing SSH"
  value       = "aws ssm start-session --target ${aws_instance.nightscout.id} --region ${var.aws_region}"
}

output "nightscout_url" {
  description = "Nightscout URL"
  value       = var.domain_name != "" ? "https://${var.domain_name}" : "http://${aws_eip.nightscout.public_ip}"
}