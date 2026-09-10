output "elastic_ip" {
  description = "Elastic IP address of the Nightscout instance"

  value = aws_eip.nightscout.public_ip
}

output "public_dns" {
  description = "AWS public DNS hostname"

  value = aws_eip.nightscout.public_dns
}

output "instance_id" {
  description = "EC2 instance ID"

  value = aws_instance.nightscout.id
}

output "ssh_command" {
  description = "SSH command for the Nightscout server"

  value = "ssh -i nightscout-key.pem ubuntu@${aws_eip.nightscout.public_ip}"
}

output "nightscout_url" {
  description = "Nightscout URL"

  value = var.domain_name != "" ? "https://${var.domain_name}" : null
}