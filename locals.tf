locals {
    master_lb_port_objects   = [
        for new_port_map in {
            for name, port_map in var.master_lb_ports_map: format("%s_%d",port_map.protocol,port_map.port) => port_map
            if contains(["tcp", "udp"], port_map.protocol) && port_map.port != ""
        }
        :
        {
            port = new_port_map.port
            protocol = new_port_map.protocol
            forward_port = var.master_ports[new_port_map.master_port_name].port
        }
        if can(var.master_ports[new_port_map.master_port_name]) && var.master_ports[new_port_map.master_port_name].protocol == new_port_map.protocol
    ]
    haproxy_master_lb_tcp_port_objects  = [
        for port_object in local.master_lb_port_objects: port_object
        if port_object.protocol == "tcp"
    ]
    worker_lb_port_objects   = [
        for new_port_map in {
            for name, port_map in var.worker_lb_ports_map: format("%s_%d",port_map.protocol,port_map.port) => port_map
            if contains(["tcp", "udp"], port_map.protocol) && port_map.port != ""
        }
        :
        {
            port = new_port_map.port
            protocol = new_port_map.protocol
            forward_port = var.worker_ports[new_port_map.worker_port_name].port
        }
        if can(var.worker_ports[new_port_map.worker_port_name]) && var.worker_ports[new_port_map.worker_port_name].protocol == new_port_map.protocol
    ]
    nginx_upstream_worker_ports = distinct([ for port_object in local.worker_lb_port_objects: port_object.forward_port ])
}
