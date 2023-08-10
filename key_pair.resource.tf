resource "aws_lightsail_key_pair" "key_pair" {
  public_key = file("./${var.ssh_key_path}.pub")
}
