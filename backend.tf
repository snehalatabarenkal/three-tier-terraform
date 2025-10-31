########################################
# Create S3 Bucket for Terraform Backend
########################################

resource "aws_s3_bucket" "terraform_state" {
  bucket = "three-terraform-state-bucket"

  tags = {
    Name = "Terraform State Bucket"
  }
}

# Enable versioning for safety (recommended)
resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "encryption" {
  bucket = aws_s3_bucket.terraform_state.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

########################################
# Create DynamoDB Table for State Locking
########################################

resource "aws_dynamodb_table" "terraform_lock" {
  name         = "ajit-inamdar-tech-terraform-backend"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name = "Terraform Lock Table"
  }
}

########################################
# Terraform Backend Configuration
########################################

# NOTE:
# Uncomment this section only AFTER running "terraform apply"
# to create the S3 bucket and DynamoDB table.
# Then run: terraform init -migrate-state

# terraform {
#   backend "s3" {
#     bucket         = "three-terraform-state-bucket"       # same as created above
#     key            = "terraform.tfstate"                  # file path inside the bucket
#     region         = "us-east-1"
#     encrypt        = true
#    dynamodb_table = "ajit-inamdar-tech-terraform-backend"  # lock table
# }
#}
