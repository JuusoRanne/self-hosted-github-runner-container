module "resource_group" {
  source         = "git@github.com:BusinessFinland/bf-terraform-modules.git//resource_group?ref=main"
  app_name       = var.app_name
  environment    = var.environment
  location_short = var.location_short
  location       = var.location
  tags           = var.tags

}
resource "azurerm_user_assigned_identity" "managed_identity" {
  location            = module.resource_group.location
  name                = "mi-euw-${var.app_name}-${var.environment}"
  resource_group_name = module.resource_group.name
}

resource "azurerm_virtual_network" "virtual_network" {
  name                = "vn-euw-${var.app_name}-${var.environment}"
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  address_space       = var.vnet_address_space

  tags = var.tags

  depends_on = [module.resource_group]

}

resource "azurerm_subnet" "subnet1" {
  name                 = "subnet-euw-${var.app_name}-${var.environment}"
  resource_group_name  = module.resource_group.name
  virtual_network_name = azurerm_virtual_network.virtual_network.name
  address_prefixes     = var.subnet_address_prefix

  delegation {
    name = "acae-delegation"

    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
  depends_on = [azurerm_virtual_network.virtual_network]
}

resource "azurerm_storage_account" "storage_account" {
  name                     = replace("st${var.app_name}${var.environment}euw", -" ", "")
  resource_group_name      = module.resource_group.name
  location                 = module.resource_group.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = var.tags

}

resource "azurerm_storage_queue" "storage_queue" {
  name                 = "gh-runner-scaler"
  storage_account_name = azurerm_storage_account.storage_account.name
  metadata             = var.tags
}

resource "azurerm_container_app_environment" "container_app_environment" {
  name                               = "cae-euw-${var.app_name}-${var.environment}"
  resource_group_name                = module.resource_group.name
  location                           = module.resource_group.location
  infrastructure_resource_group_name = "${module.resource_group.name}-managed"
  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }
  infrastructure_subnet_id = azurerm_subnet.subnet1.id

  tags = var.tags



}

resource "azurerm_container_app" "self_hosted_git_runner" {
  name                         = "ca-euw-${var.app_name}-${var.environment}"
  container_app_environment_id = azurerm_container_app_environment.container_app_environment.id
  resource_group_name          = module.resource_group.name
  revision_mode                = "Single"
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.managed_identity.id]
  }

  registry {
    server   = var.acr_login_server
    identity = azurerm_user_assigned_identity.managed_identity.id
  }

  template {
    min_replicas = 1
    container {
      name   = "self-hosted-gh-runner"
      image  = "${var.acr_login_server}/infrastructure/github-runner:${var.acr_tag}"
      cpu    = var.container_cpu
      memory = var.container_memory
    }


  }
  depends_on = [azurerm_container_app_environment.container_app_environment]
}
