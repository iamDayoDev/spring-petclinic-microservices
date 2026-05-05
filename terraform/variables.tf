variable "aws_region" {
  default = "us-east-1"
}

variable "cluster_name" {
  default = "petclinic-eks"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "environment" {
  default = "production"
}

variable "services" {
  type = list(string)
  default = [
    "config-server",
    "discovery-server",
    "api-gateway",
    "customers-service",
    "vets-service",
    "visits-service",
    "admin-server"
  ]
}