resource "local_file" "worker_nginx_conf" {
  filename = "${path.module}/worker.nginx.conf"
  depends_on = [ 
    aws_lightsail_instance.worker,
  ]
  file_permission = "0777"
  # https://developer.hashicorp.com/terraform/language/functions/templatefile
  content  = <<EOT
user www-data;
worker_processes auto;
pid /run/nginx.pid;
###############################################################################################################
# https://www.cyberciti.biz/faq/linux-unix-nginx-too-many-open-files/
# Must be less than LimitNOFILE for systemd 
# or /etc/security/limits.conf (non-systemd)
# E.g. if LimitNOFILE is 65535, I set to 30000 (systemd)
# E.g. if "nginx       hard    nofile  30000" in the  /etc/security/limits.conf, I set to 30000 (non-systemd)
###############################################################################################################
worker_rlimit_nofile 30000; #vg
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 65535;
    # multi_accept on;
}
stream {
    %{ for worker_port in local.nginx_upstream_worker_ports}
    upstream ipv4_worker_port_${worker_port}_servers {
        least_conn;
        %{ for index, instance in aws_lightsail_instance.worker }
        server ${instance.private_ip_address}:${worker_port};
        %{ endfor }
    }
    upstream ipv6_worker_port_${worker_port}_servers {
        least_conn;
        %{ for index, instance in aws_lightsail_instance.worker }
        server [${instance.ipv6_addresses[0]}]:${worker_port};
        %{ endfor }
    }
    %{ endfor }

    %{ for port_object in local.worker_lb_port_objects}
    server {
        listen  ${port_object.port} ${port_object.protocol=="udp" ? "udp" : ""};
        proxy_pass    ipv4_worker_port_${port_object.forward_port}_servers;
        proxy_timeout 3s;
        proxy_connect_timeout 1s;
    }
    server {
        listen  [::]:${port_object.port}  ${port_object.protocol=="udp" ? "udp" : ""};
        proxy_pass    ipv6_worker_port_${port_object.forward_port}_servers;
        proxy_timeout 3s;
        proxy_connect_timeout 1s;
    }
    %{ endfor }
}
  EOT
}