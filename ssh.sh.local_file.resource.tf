resource "local_file" "ssh_sh" {
  filename = "${path.module}/ssh.sh"
  depends_on = [ 
    aws_lightsail_instance.master,
    aws_lightsail_instance.master_lb,
    aws_lightsail_instance.worker,
    aws_lightsail_instance.worker_lb,
  ]
  file_permission = "0777" # It does not actually work, got -rwxr-xr-x.
  content  = templatefile("${path.module}/ssh.sh.tftpl", {
    sshkeypath = "${var.ssh_key_path}.pem",
    myarray = join(" ", flatten([for nodes in [
        aws_lightsail_instance.master,
        aws_lightsail_instance.master_lb,
        aws_lightsail_instance.worker,
        aws_lightsail_instance.worker_lb,
    ]: [for node in nodes : "${node.name}-${node.private_ip_address}-${node.username}@${node.public_ip_address}"]])),
  })
}