variable "project" { }


# create terraform user, generate keys, apply iam policy for s3 access
resource "aws_iam_user" "user" {
  name = "${format("terraform-%s", var.project)}"
}

# generate keys for terraform user
resource "aws_iam_access_key" "user_keys" {
  user = "${format("terraform-%s", var.project)}"
  depends_on = ["aws_iam_user.user"]
}

# terraform user policy for rw of bucket, and ro for other buckets
resource "aws_iam_user_policy" "terraform_policy" {
  name = "${format("terraform-%s", var.project)}"
  user = "${format("terraform-%s", var.project)}"
  depends_on = ["aws_iam_user.user"]
  policy= <<EOF
{
  "Version": "2012-10-17",
    "Statement": [

      {
        "Effect": "Allow",
        "Action": "s3:ListBucket",
        "Resource": "arn:aws:s3:::terraform-remote-state-s3-*"
      },
      {
        "Effect": "Allow",
        "Action": ["s3:GetObject"],
        "Resource": [
        "arn:aws:s3:::terraform-remote-state-s3-*",
        "arn:aws:s3:::terraform-remote-state-s3-*/*"
        ]
      },
      {
        "Effect": "Allow",
        "Action": ["s3:PutObject"],
        "Resource": [
        "arn:aws:s3:::terraform-remote-state-s3-${var.project}",
        "arn:aws:s3:::terraform-remote-state-s3-${var.project}/*"
        ]
      }
   ]
}
EOF
}


# create an S3 bucket for storing state file
resource "aws_s3_bucket" "terraform-state-s3" {
  bucket = "${format("terraform-remote-state-s3-%s", var.project)}"
  force_destroy = true
  versioning {
    enabled = true
  }
  lifecycle {
    #prevent_destroy = true
    #prevent_destroy = false
  }

  tags {
   Name = "${format("%s - terraform remote state in s3", var.project)}"
  }
}


# create a dynamodb table for state locking
resource "aws_dynamodb_table" "terraform-state-lock-dynamodb" {
  name = "terraform-state-lock-dynamodb-${var.project}"
  read_capacity = 20
  write_capacity = 20
  hash_key = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
  lifecycle {
    #prevent_destroy = true
    #prevent_destroy = false
  }

  tags {
    Name = "${format("%s - dynamoDB terraform state lock table", var.project)}"
    Environment = "${var.project}"
  }
}



/*
output "bucket" {
  value = "${aws_s3_bucket.terraform-state-s3.id}"
}

output "dynamodb_table" {
  value = "${aws_dynamodb_table.terraform-state-lock-dynamodb.id}"
}
*/
