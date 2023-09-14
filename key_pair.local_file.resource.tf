resource "local_file" "private_key_openssh" {
  filename = "${path.module}/${var.ssh_key_path}.pem"
  file_permission = "0400"
  content  = aws_lightsail_key_pair.key_pair.private_key
}
resource "local_file" "public_key_openssh" {
  filename = "${path.module}/${var.ssh_key_path}.pub"
  file_permission = "0400"
  content  = aws_lightsail_key_pair.key_pair.public_key
}
