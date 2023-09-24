# variable will be set by local environment.
# For example: EXAMPLEVAR will be set by TF_VAR_EXAMPLEVAR
variable "AWS_ACCESS_KEY" {
  type = string
}
variable "AWS_SECRET_KEY" {
  type = string
}

variable "default_region" {
  default = "ap-southeast-1"
}

variable "default_name" {
  default = "tf_k8s"
}

variable "ssh_key_path" {
  default = "./tf_k8s"
}

# Reference terraform aws lightsail
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lightsail_instance.html

variable "master_count" {
  default = 3
}

variable "master_blueprint_id" {
  default = "debian_11"
}
variable "master_bundle_id" {
  default = "medium_3_0"
}
variable master_ports {
  type = map(object({
    protocol  = string
    port      = number
    is_public = bool
  }))
  default = {
    # Just change port if need
    # SSH port
    ssh = { protocol = "tcp", port = 22, is_public = true },
    # TCP	Inbound	2379-2380	etcd server client API	kube-apiserver, etcd
    etcd_1 = { protocol = "tcp", port = 2379, is_public = false },
    etcd_2 = { protocol = "tcp", port = 2380, is_public = false },
    # Kube API server
    tcp_api = { protocol = "tcp", port = 6443, is_public = false },
  }
}

variable "master_lb_count" {
  default = 1
}

variable "master_lb_blueprint_id" {
  default = "debian_11"
}
variable "master_lb_bundle_id" {
  default = "nano_3_0"
}
variable master_lb_ports {
  type = map(object({
    protocol  = string
    port      = number
    is_public = bool
  }))
  default = {
    # Just change port if need
    # SSH port
    ssh = { protocol = "tcp", port = 22, is_public = true},
    # Port for haproxy stats
    tcp_stats = { protocol = "tcp", port = 9000, is_public = true},
    # Port for grafana ui
    grafana_ui = { protocol = "tcp", port = 3000, is_public = true},
  }
}
variable master_lb_ports_map {
  type = map(object({
    protocol          = string
    port              = number
    is_public = bool
    master_port_name  = string
  }))
  default = {
    # Just change port if need
    # Kube API server
    tcp_api_server = { protocol = "tcp", port = 6443, is_public = true, master_port_name = "tcp_api" },
  }
}

variable "worker_count" {
  default = 3
}

variable "worker_blueprint_id" {
  # amazon_linux_2023
  default = "debian_11"
}
variable "worker_bundle_id" {
  default = "medium_3_0"
}
variable worker_ports {
  type = map(object({
    protocol  = string
    port      = number
    is_public = bool
  }))
  default = {
    # Just change port if need
    # SSH port
    ssh = { protocol = "tcp", port = 22, is_public = true},
    # kubernetes NodePort range 30000-32767
    ingress_tcp_http = { protocol = "tcp", port = 30080, is_public = false},
    ingress_tcp_https = { protocol = "tcp", port = 30443, is_public = false},
  }
}

variable "worker_lb_count" {
  default = 1
}

variable "worker_lb_blueprint_id" {
  # amazon_linux_2023
  default = "debian_11"
}
variable "worker_lb_bundle_id" {
  default = "nano_3_0"
}
variable worker_lb_ports {
  type = map(object({
    protocol  = string
    port      = number
    is_public = bool
  }))
  default = {
    # Just change port if need
    # SSH port
    ssh = { protocol = "tcp", port = 22, is_public = true},
  }
}

variable worker_lb_ports_map {
  type = map(object({
    protocol          = string
    port              = number
    is_public         = bool
    worker_port_name  = string
  }))
  default = {
    # Just change port if need
    # SSH port
    http = { protocol = "tcp", port = 80, is_public = true, worker_port_name = "ingress_tcp_http" },
    https = { protocol = "tcp", port = 443, is_public = true, worker_port_name = "ingress_tcp_https"},
  }
}

variable "user_data" {
  default = ""
}

