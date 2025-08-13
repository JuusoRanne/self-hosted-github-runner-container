app_name = "self-hosted-gh-runner"

environment = "prod"

location_short = "euw"

tags = {
  # Your environment specific tags should go here
  "application_purpose" = "Self-hosted GitHub Runner"
  "creator" = "Juuso Ranne"
  "environment" = "Development"
}

vnet_address_space = ["10.0.0.0/16"]

subnet_address_prefix = ["10.0.0.0/24"]

