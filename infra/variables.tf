variable "key_name" {
  description = "The name of the SSH key pair to use for the EC2 instances."
  type        = string
  default     = "k8s-key"
}

variable "aws_access_key" {
  description = "AWS Access Key ID."
  type        = string
}

variable "aws_secret_key" {
  description = "AWS Secret Access Key."
  type        = string
}

variable "region" {
  description = "AWS region to deploy the resources."
  type        = string
  default     = "us-east-1"
}

variable "ami_id" {
  description = "The AMI ID to use for the EC2 instances."
  type        = string
  default     = "ami-020cba7c55df1f615" # Ubuntu Server 24.04 LTS in us-east-1
}
