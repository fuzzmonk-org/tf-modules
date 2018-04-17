variable "env" { }
variable kubernetes_ver { }
variable kops_s3 { }
variable kops_iam { }
variable kops_name { }

variable kops_network { }
variable kops_topology { }

variable kops_vpc { }
variable kops_zones { default = [] }
variable kops_subnets { }
variable kops_utility_subnets { }

variable kops_master_size { }
variable kops_node_size { }
variable kops_node_count { }

variable kops_dns_type { }
variable kops_dns_zone { }

variable kops_api_loadbalancer_type { }


resource "aws_s3_bucket" "kops-k8s-state-s3" {
  bucket = "${format("kops-k8s-state-s3-%s", var.env)}"
  force_destroy = true
  versioning {
    enabled = true
  }
  tags {
   Name = "${format("%s - KOPS/Kubernetes remote state in s3", var.env)}"
   Environment = "${var.env}"
  }
}


/*

*/
