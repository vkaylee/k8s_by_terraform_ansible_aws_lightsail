resource "aws_lightsail_instance_public_ports" "master" {
  count = length(aws_lightsail_instance.master)
  instance_name = aws_lightsail_instance.master[count.index].name
  port_info {
    protocol = "tcp"
    from_port = 22
    to_port = 22
  }
  # TCP	Inbound	2379-2380	etcd server client API	kube-apiserver, etcd
  port_info {
    protocol = "tcp"
    from_port = 2379
    to_port = 2380
  }
  port_info {
    protocol = "tcp"
    from_port = 6443
    to_port = 6443
  }
  # port_info {
  #   protocol = "tcp"
  #   from_port = 10250
  #   to_port = 10252
  # }
  # port_info {
  #   protocol = "tcp"
  #   from_port = 10255
  #   to_port = 10255
  # }
}

resource "aws_lightsail_instance_public_ports" "master_lb" {
  count = length(aws_lightsail_instance.master_lb)
  instance_name = aws_lightsail_instance.master_lb[count.index].name
  port_info {
    protocol = "tcp"
    from_port = 22
    to_port = 22
  }
  port_info {
    protocol = "tcp"
    from_port = 6443
    to_port = 6443
  }
  # Port for haproxy stats
  port_info {
    protocol = "tcp"
    from_port = 9000
    to_port = 9000
  }
}

resource "aws_lightsail_instance_public_ports" "worker" {
  count = length(aws_lightsail_instance.worker)
  instance_name = aws_lightsail_instance.worker[count.index].name
  port_info {
    protocol = "tcp"
    from_port = 22
    to_port = 22
  }
  # port_info {
  #   protocol = "tcp"
  #   from_port = 80
  #   to_port = 80
  # }
  # port_info {
  #   protocol = "tcp"
  #   from_port = 10250
  #   to_port = 10250
  # }
}

resource "aws_lightsail_instance_public_ports" "worker_lb" {
  count = length(aws_lightsail_instance.worker_lb)
  instance_name = aws_lightsail_instance.worker_lb[count.index].name
  port_info {
    protocol = "tcp"
    from_port = 22
    to_port = 22
  }
  # port_info {
  #   protocol = "tcp"
  #   from_port = 80
  #   to_port = 80
  # }
}
