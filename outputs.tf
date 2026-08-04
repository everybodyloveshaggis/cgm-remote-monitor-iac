output "elastic_ip" {
  description = "Public IP of the Nightscout instance — point your domain's A record here"
  value       = aws_eip.nightscout.public_ip
}

output "public_dns" {
  description = "AWS-assigned public DNS hostname (stable, tied to the Elastic IP). Use this in place of a domain_name if you don't own one."
  value       = aws_eip.nightscout.public_dns
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.nightscout.id
}

output "ssh_command" {
  description = "Command to SSH into the instance"
  value       = "ssh -i ${var.key_name}.pem ubuntu@${aws_eip.nightscout.public_ip}"
}
