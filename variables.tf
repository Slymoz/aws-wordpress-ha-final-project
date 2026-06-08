variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix for infrastructure component nomenclature"
  type        = string
  default     = "wp-ha-final"
}

variable "instance_type" {
  description = "EC2 computing sizing unit for the scaling servers"
  type        = string
  default     = "t3.micro"
}

variable "db_name" {
  description = "Database namespace matching cloud compliance constraints"
  type        = string
  default     = "wordpressdb"
}

variable "db_master_username" {
  description = "Master database access group identity username"
  type        = string
  default     = "wpadmin"
}

variable "db_master_password" {
  description = "Database entry security password passphrase token"
  type        = string
  sensitive   = true
}
