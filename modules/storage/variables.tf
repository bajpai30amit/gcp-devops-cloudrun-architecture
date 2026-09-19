variable "project_id" {
  type = string
}

variable "bucket_name" {
  type = string

  validation {
    condition     = length(var.bucket_name) >= 3
    error_message = "Bucket name must contain at least 3 characters."
  }
}

variable "location" {
  type    = string
  default = "US"
}