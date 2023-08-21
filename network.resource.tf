resource "aws_lightsail_instance_public_ports" "master" {
  for_each = { for index, instance in aws_lightsail_instance.master: index => instance }
  instance_name = each.value.name
  dynamic "port_info" {
    for_each = var.master_ports
    content {
      from_port = port_info.value.port
      to_port   = port_info.value.port
      protocol  = port_info.value.protocol
    }
  }
}

resource "aws_lightsail_instance_public_ports" "master_lb" {
  for_each = { for index, instance in aws_lightsail_instance.master_lb: index => instance }
  instance_name = each.value.name
  dynamic "port_info" {
    for_each = {
      for name, port_object in merge(var.master_lb_ports, var.master_lb_ports_map): format("%s_%d",port_object.protocol,port_object.port) => port_object
      if contains(["tcp", "udp"], port_object.protocol) && port_object.port != ""
    }
    content {
      from_port = port_info.value.port
      to_port   = port_info.value.port
      protocol  = port_info.value.protocol
    }
  }
}

resource "aws_lightsail_instance_public_ports" "worker" {
  for_each = { for index, instance in aws_lightsail_instance.worker: index => instance }
  instance_name = each.value.name
  dynamic "port_info" {
    for_each = var.worker_ports
    content {
      from_port = port_info.value.port
      to_port   = port_info.value.port
      protocol  = port_info.value.protocol
    }
  }
}

resource "aws_lightsail_instance_public_ports" "worker_lb" {
  for_each = { for index, instance in aws_lightsail_instance.worker_lb: index => instance }
  instance_name = each.value.name
  dynamic "port_info" {
    for_each = {
      for name, port_object in merge(var.worker_lb_ports, var.worker_lb_ports_map): format("%s_%d",port_object.protocol,port_object.port) => port_object
      if contains(["tcp", "udp"], port_object.protocol) && port_object.port != ""
    }
    content {
      from_port = port_info.value.port
      to_port   = port_info.value.port
      protocol  = port_info.value.protocol
    }
  }
}
