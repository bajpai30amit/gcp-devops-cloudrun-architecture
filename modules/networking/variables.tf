variable "project_id" {
  type = string
}

variable "network_name" {
  type = string
}

variable "region" {
  type = string
}

variable "subnet_name" {
  type = string
}

variable "subnet_cidr" {
  type    = string
  default = "10.10.0.0/24"
}