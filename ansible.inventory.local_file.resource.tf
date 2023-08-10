resource "local_file" "ansible_inventory" {
  filename = "${path.module}/ansible.inventory.cfg"
  depends_on = [ 
    aws_lightsail_instance.master,
    aws_lightsail_instance.master_lb,
    aws_lightsail_instance.worker,
    aws_lightsail_instance.worker_lb,
  ]
  file_permission = "0777" # It does not actually work, got -rwxr-xr-x.
  # content  = templatefile("${path.module}/ansible_inventory.tftpl", {
  #   aws_lightsail_instances = aws_lightsail_instance.master
  # })
  content  = <<EOT
[masters]
%{ for k, instance in aws_lightsail_instance.master }
master_${k + 1} ansible_host=${instance.public_ip_address} private_ip=${instance.private_ip_address} ansible_user=${instance.username} ansible_ssh_private_key_file=${var.ssh_key_path}
%{ endfor }
[master_lbs]
%{ for k, instance in aws_lightsail_instance.master_lb }
master_lb_${k + 1} ansible_host=${instance.public_ip_address} private_ip=${instance.private_ip_address} ansible_user=${instance.username} ansible_ssh_private_key_file=${var.ssh_key_path}
%{ endfor }
[workers]
%{ for k, instance in aws_lightsail_instance.worker }
worker_${k + 1} ansible_host=${instance.public_ip_address} private_ip=${instance.private_ip_address} ansible_user=${instance.username} ansible_ssh_private_key_file=${var.ssh_key_path}
%{ endfor }
[worker_lbs]
%{ for k, instance in aws_lightsail_instance.worker_lb }
worker_lb_${k + 1} ansible_host=${instance.public_ip_address} private_ip=${instance.private_ip_address} ansible_user=${instance.username} ansible_ssh_private_key_file=${var.ssh_key_path}
%{ endfor }
EOT
}