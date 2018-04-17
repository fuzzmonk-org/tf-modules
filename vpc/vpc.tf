variable "cidr_block" { }
variable "enable_dns_support" { }
variable "enable_dns_hostnames" { }
variable "env" { }
variable "azs" {default = []}
variable "admin_net" {default = []}
variable "build_net" {default = []}
variable "public_net" {default = []}
variable "private_net" {default = []}

terraform {
  required_version = ">= 0.11.0"
}




###########
# VPC
###########
resource "aws_vpc" "vpc" {
  cidr_block = "${var.cidr_block}"
  instance_tenancy = "default"
  enable_dns_support = "${var.enable_dns_support}"
  enable_dns_hostnames = "${var.enable_dns_hostnames}"

  tags {
    Name = "${format("%s_vpc", var.env)}"
  }
}


output "vpc_id" {
  value = "${aws_vpc.vpc.id}"
}

output "vpc_cidr" {
  value = "${aws_vpc.vpc.cidr_block}"
}





#################################
# INTERNET AND NAT GATEWAYS
#################################
resource "aws_internet_gateway" "ig" {
  vpc_id = "${aws_vpc.vpc.id}"

  tags {
    Name = "${format("%s_ig", var.env)}"
  }
}

resource "aws_eip" "eip" {
  count = "${length(var.azs)}"
  vpc = true
  depends_on = ["aws_internet_gateway.ig"]

  tags {
    Name = "${format("%s_eip_%s", var.env, element(var.azs, count.index))}"
  }
}

resource "aws_nat_gateway" "nat_gw" {
  count = "${length(var.azs)}"
  allocation_id = "${element(aws_eip.eip.*.id, count.index)}"
  subnet_id = "${element(aws_subnet.public_net.*.id, count.index)}"
  depends_on = ["aws_internet_gateway.ig"]
}


output "ig_id" {
  value = "${aws_internet_gateway.ig.id}"
}


output "azs" {
  value = "${var.azs}"
}






###########
# SUBNETS
###########
resource "aws_subnet" "admin_net" {
  count = "${length(var.admin_net)}"
  vpc_id = "${aws_vpc.vpc.id}"
  cidr_block = "${var.admin_net[count.index]}"
  availability_zone = "${element(var.azs, count.index)}"

  tags = {
    Name =  "${format("%s_admin_net-%s", var.env, var.azs[count.index])}"
    Environment = "${var.env}"
  }
}

resource "aws_subnet" "build_net" {
  count = "${length(var.build_net)}"
  vpc_id = "${aws_vpc.vpc.id}"
  cidr_block = "${var.build_net[count.index]}"
  availability_zone = "${element(var.azs, count.index)}"

  tags = {
    Name =  "${format("%s_build_net-%s", var.env, var.azs[count.index])}"
    Environment = "${var.env}"
  }
}

resource "aws_subnet" "public_net" {
  count = "${length(var.public_net)}"
  vpc_id = "${aws_vpc.vpc.id}"
  cidr_block = "${var.public_net[count.index]}"
  availability_zone = "${element(var.azs, count.index)}"
  map_public_ip_on_launch = true

  tags = {
    Name =  "${format("%s_public_net-%s", var.env, var.azs[count.index])}"
    Environment = "${var.env}"
  }
}

resource "aws_subnet" "private_net" {
  count = "${length(var.private_net)}"
  vpc_id = "${aws_vpc.vpc.id}"
  cidr_block = "${var.private_net[count.index]}"
  availability_zone = "${element(var.azs, count.index)}"

  tags = {
    Name =  "${format("%s_private_net-%s", var.env, var.azs[count.index])}"
    Environment = "${var.env}"
  }
}



output "admin_net" {
  value = "${aws_subnet.admin_net.*.id}"
}

output "build_net" {
  value = "${aws_subnet.build_net.*.id}"
}

output "public_net" {
  value = "${aws_subnet.public_net.*.id}"
}

output "private_net" {
  value = "${aws_subnet.private_net.*.id}"
}





###########
# ROUTING
###########
resource "aws_route" "main_route" {
  route_table_id = "${aws_vpc.vpc.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = "${aws_internet_gateway.ig.id}"
}

resource "aws_route_table" "public_route" {
  vpc_id = "${aws_vpc.vpc.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.ig.id}"
  }
  tags {
    Name = "public route"
  }
}

resource "aws_route_table" "private_route" {
  count = "${length(var.azs)}"
  vpc_id = "${aws_vpc.vpc.id}"
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = "${element(aws_nat_gateway.nat_gw.*.id, count.index)}"
  }
  tags {
    Name = "${format("nat_route-%s", element(aws_nat_gateway.nat_gw.*.id, count.index))}"
  }
}

resource "aws_route_table_association" "public_route" {
  count = "${length(var.public_net)}"
  subnet_id = "${element(aws_subnet.public_net.*.id, count.index)}"
  route_table_id = "${aws_route_table.public_route.id}"
}

resource "aws_route_table_association" "admin_route" {
  count = "${length(var.admin_net)}"
  subnet_id = "${element(aws_subnet.admin_net.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.private_route.*.id, count.index)}"
}

resource "aws_route_table_association" "build_route" {
  count = "${length(var.build_net)}"
  subnet_id = "${element(aws_subnet.build_net.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.private_route.*.id, count.index)}"
}

resource "aws_route_table_association" "private_route" {
  count = "${length(var.private_net)}"
  subnet_id = "${element(aws_subnet.private_net.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.private_route.*.id, count.index)}"
}


output "test" {
  value = "${aws_subnet.public_net.*.id}"
}




###########
# ACL
###########
resource "aws_network_acl" "all" {
  vpc_id = "${aws_vpc.vpc.id}"

    egress {
      protocol = "-1"
      rule_no = 200
      action = "allow"
      cidr_block =  "0.0.0.0/0"
      from_port = 0
      to_port = 0
    }

    ingress {
      protocol = "-1"
      rule_no = 100
      action = "allow"
      cidr_block =  "0.0.0.0/0"
      from_port = 0
      to_port = 0
    }

    tags {
        Name = "wide open acl; use security groups unless there's a huge emergency"
    }
}




