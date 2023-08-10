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

variable "master_lb_count" {
  default = 1
}

variable "master_lb_blueprint_id" {
  default = "debian_11"
}
variable "master_lb_bundle_id" {
  default = "nano_3_0"
}

variable "worker_count" {
  default = 3
}

variable "worker_blueprint_id" {
  default = "debian_11"
}
variable "worker_bundle_id" {
  default = "medium_3_0"
}

variable "worker_lb_count" {
  default = 1
}

variable "worker_lb_blueprint_id" {
  default = "debian_11"
}
variable "worker_lb_bundle_id" {
  default = "nano_3_0"
}

variable "user_data" {
  default = ""
}

