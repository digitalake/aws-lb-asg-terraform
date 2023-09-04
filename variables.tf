variable "asg_image_id" {
  type        = string
  description = "An image to use while launching the ASG instance."

  validation {
    condition     = length(var.asg_image_id) > 4 && substr(var.asg_image_id, 0, 4) == "ami-"
    error_message = "The image_id value must be a valid AMI id, starting with \"ami-\"."
  }
}

variable "asg_instance_type" {
  type        = string
  description = "the type ec2 type for asg"
  default     = "t2.micro"
}

variable "allow_ssh_from_cidr" {
  default = ["0.0.0.0/0"]
  description = "CIDR to access instances from (for testing)"
}

variable "naming_prefix" {
  default     = "asg-lab"
  description = "prefix for resource naming"
}

variable "ssh_pub_key_path" {
  description = "Path for the public ssh key will be used for connections"
}