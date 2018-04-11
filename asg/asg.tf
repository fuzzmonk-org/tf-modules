resource "aws_launch_configuration" "lc" {
  name_prefix          = "bastion-"
  image_id             = "${var.bastion_ami}"
  instance_type        = "t2.micro"
  key_name = "${var.key_name}"
  #user_data            = "foo"

  security_groups = [
    "${aws_security_group.bastion.id}"
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "asg" {
  name                 = "bastion-asg"
  launch_configuration = "${aws_launch_configuration.bastion-lc.name}"
  min_size             = 1
  max_size             = 1
  vpc_zone_identifier  = ["${var.bastion_subnet}"]

  lifecycle {
    create_before_destroy = true
  }

  tags {
    Name = "${format("%s_bastion_asg", var.bastion_env)}"
  }
}
