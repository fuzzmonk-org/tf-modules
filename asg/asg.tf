resource "aws_launch_configuration" "lc" {
  name_prefix          = "foo-"
  image_id             = "${var.ami}"
  instance_type        = "t2.micro"
  key_name = "${var.key_name}"

  security_groups = [
    "${aws_security_group.foo.id}"
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "asg" {
  name                 = "foo-asg"
  launch_configuration = "${aws_launch_configuration.lc.name}"
  min_size             = 1
  max_size             = 1
  vpc_zone_identifier  = ["${var.subnet}"]

  lifecycle {
    create_before_destroy = true
  }

  tags {
    Name = "${format("%s_foo_asg", var.env)}"
  }
}
