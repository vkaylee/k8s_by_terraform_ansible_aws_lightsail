resource "local_file" "worker_nginx_conf" {
  filename = "${path.module}/worker.nginx.conf"
  depends_on = [ 
    aws_lightsail_instance.worker,
  ]
  file_permission = "0777"
  content  = <<EOT
stream {
    upstream worker_port_80_servers {
        least_conn;
        %{ for index, instance in aws_lightsail_instance.worker }
        server ${instance.private_ip_address}:80;
        %{ endfor }
    }
    
    server {
        listen  80;
        proxy_pass    worker_port_80_servers;
        proxy_timeout 3s;
        proxy_connect_timeout 1s;
    }
}
  EOT
}