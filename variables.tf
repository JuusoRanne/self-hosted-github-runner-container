variable "app_name" {
  description = "The application name"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "location_short" {
  description = "Short string representing the location of the resources"
  type        = string
  default     = "WEU"
}

variable "location" {
  description = "Geographical location where resources will be created"
  type        = string
  default     = "West Europe"
}

variable "tags" {
  description = "A map of tags to assign to resources"
  type = object({
    application_purpose = string
    business_owner      = string
    cost_centre         = number
    creator             = string
    environment         = string
    owner               = string
    partner             = string
    project_name        = string
  })
}

variable "vnet_address_space" {
  description = "The address space for the virtual network"
  type        = list(string)
  default     = [""]
}

variable "subnet_address_prefix" {
  description = "The address prefix for the subnet"
  type        = list(string)
  default     = [""]
}

variable "acr_login_server" {
  description = "The login server for the Azure Container Registry"
  type        = string
}

variable "acr_tag" {
  description = "The tag for the Azure Container Registry"
  type        = string
}

variable "container_cpu" {
  description = "The CPU value for librechat container"
  type = string
  default = "0.5"
}

variable "container_memory" {
  description = "The memory value for librechat container"
  type = string
  default = "1.0Gi"
}

variable "app_id" {
  description = "GitHub App ID"
  type        = string
  sensitive   = true
}

variable "app_private_key" {
  description = "GitHub App private key"
  type        = string
  sensitive   = true
}

variable "runner_name" {
  description = "Name for the GitHub runner instance"
  type        = string
}

variable "gh_owner" {
  description = "GitHub organization name"
  type        = string
}
