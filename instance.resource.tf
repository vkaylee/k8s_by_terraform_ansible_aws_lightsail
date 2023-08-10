resource "aws_lightsail_instance" "master" {
	count             = var.master_count
	name              = "${var.default_name}_master_${count.index + 1}"
  availability_zone = data.aws_availability_zones.available.names[count.index%length(data.aws_availability_zones.available.names)]
  blueprint_id      = var.master_blueprint_id
  bundle_id         = var.master_bundle_id
  key_pair_name     = aws_lightsail_key_pair.key_pair.name
  user_data         = var.user_data
}

resource "aws_lightsail_instance" "master_lb" {
  count             = var.master_lb_count
  name              = "${var.default_name}_master_lb_${count.index + 1}"
  availability_zone = data.aws_availability_zones.available.names[count.index%length(data.aws_availability_zones.available.names)]
  blueprint_id      = var.master_lb_blueprint_id
  bundle_id         = var.master_lb_bundle_id
  key_pair_name     = aws_lightsail_key_pair.key_pair.name
  user_data         = var.user_data
}

resource "aws_lightsail_instance" "worker" {
  count             = var.worker_count
  name              = "${var.default_name}_worker_${count.index + 1}"
  availability_zone = data.aws_availability_zones.available.names[count.index%length(data.aws_availability_zones.available.names)]
  blueprint_id      = var.worker_blueprint_id
  bundle_id         = var.worker_bundle_id
  key_pair_name     = aws_lightsail_key_pair.key_pair.name
  user_data         = var.user_data
}

resource "aws_lightsail_instance" "worker_lb" {
  count             = var.worker_lb_count
  name              = "${var.default_name}_worker_lb_${count.index + 1}"
  availability_zone = data.aws_availability_zones.available.names[count.index%length(data.aws_availability_zones.available.names)]
  blueprint_id      = var.worker_lb_blueprint_id
  bundle_id         = var.worker_lb_bundle_id
  key_pair_name     = aws_lightsail_key_pair.key_pair.name
  user_data         = var.user_data
}
