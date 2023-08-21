resource "local_file" "master_haproxy_cfg" {
  filename = "${path.module}/master.haproxy.cfg"
  depends_on = [ 
    aws_lightsail_instance.master,
  ]
  content  = <<EOT
global
  log 127.0.0.1:514  local0 info
  chroot /var/lib/haproxy
  pidfile /var/run/haproxy.pid
  maxconn 4000
  user haproxy
  group haproxy
  daemon
  stats socket /var/lib/haproxy/stats

defaults
  log global
  option  httplog
  option  dontlognull
  timeout connect 5000
  timeout client 50000
  timeout server 50000

frontend kube-apiserver
  bind :::6443 v4v6
  mode tcp
  option tcplog
  default_backend kube-apiserver

backend kube-apiserver
  mode tcp
  option tcp-check
  balance roundrobin
  default-server inter 10s downinter 5s rise 2 fall 2 slowstart 60s maxconn 250 maxqueue 256 weight 100
  %{ for index, instance in aws_lightsail_instance.master }
  server kube-apiserver-${index + 1} ${instance.private_ip_address}:6443 check
  %{ endfor }
EOT
}
