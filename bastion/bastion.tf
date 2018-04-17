variable azs {default = []}
variable key_name {}
variable bastion_ami_owner {} 
variable bastion_env {}
variable bastion_vpc_id {}
variable bastion_subnet {default = []}
variable dns_ext_zone_name {}
variable dns_int_zone_name {}
variable ttl {}
variable ig_id {}
variable iam_instance_profile {}


###########
# BASTION
###########
data "aws_ami" "bastion_ami" {
  most_recent = true
  owners = ["${var.bastion_ami_owner}"]
  filter {
    name = "name"
    values = ["bastion_*"]
  }
}

resource "aws_instance" "bastion" {
  count = "${length(var.azs)}"
  ami = "${data.aws_ami.bastion_ami.id}"
  instance_type = "t2.micro"
  associate_public_ip_address = "true"
  subnet_id = "${element(var.bastion_subnet, count.index)}"
  vpc_security_group_ids = ["${aws_security_group.bastion.id}"]
  key_name = "${var.key_name}"
  iam_instance_profile = "${var.iam_instance_profile}"
  
  tags {
    Name = "${format("bastion_%s", var.azs[count.index])}"
  }
}

resource "aws_eip" "bastion" {
  vpc = true

  tags {
    Name = "${format("%s_bastion_eip", var.bastion_env)}"
  }
}

resource "aws_eip_association" "bastion" {
  instance_id   = "${aws_instance.bastion.*.id[0]}"
  allocation_id = "${aws_eip.bastion.id}"
}

# probably don't need this
output "bastion_eip_id" {
  value = "${aws_eip.bastion.id}"
}


resource "aws_security_group" "bastion" {
  name = "bastion"
  description = "ssh"
  vpc_id = "${var.bastion_vpc_id}"

  ingress {
    from_port   = "22"
    to_port     = "22"
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle { create_before_destroy = true }

  tags { 
    Name = "bastion acl"
  }
}

output "bastion_public_ip" {
  value = "${aws_instance.bastion.*.public_ip}"
}


##############
# BASTION DNS
##############
# external dns is already created
data "aws_route53_zone" "ext_dns" {
  name = "${format("%s.%s", var.bastion_env, var.dns_ext_zone_name)}"
  private_zone = false
}

# adding vpc_id creates a private zone by default
resource "aws_route53_zone" "int_dns" {
  name = "${var.dns_int_zone_name}"
  vpc_id = "${var.bastion_vpc_id}"
  comment = "dns zone managed by terraform"
}

# will move to asg
resource "aws_route53_record" "bastion_master" {
   #count = "${length(var.azs)}"
   count = 1
   zone_id = "${data.aws_route53_zone.ext_dns.zone_id}"
   name = "bastion"
   type = "CNAME"
   ttl = "${var.ttl}"
   records = ["${format("bastion_%s.%s.%s", element(var.azs, count.index), var.bastion_env, var.dns_ext_zone_name)}"]
   depends_on = ["aws_eip_association.bastion"]
}

resource "aws_route53_record" "bastion" {
   count = "${length(var.azs)}"
   zone_id = "${data.aws_route53_zone.ext_dns.zone_id}"
   name = "${format("bastion_%s", element(var.azs, count.index))}"
   type = "A"
   ttl = "${var.ttl}"
   records = ["${element(aws_instance.bastion.*.public_ip, count.index)}"]
   depends_on = ["aws_eip_association.bastion"]
}