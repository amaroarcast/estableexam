locals {
  rg_name = coalesce(var.rg_name, "${var.prefix}-rg")
}


data "azurerm_client_config" "current" {}

resource "random_string" "sfx" {
  length  = 5
  upper   = false
  special = false
}

# ---------- Resource Group ----------
resource "azurerm_resource_group" "rg" {
  name     = local.rg_name
  location = var.location
}

# ---------- Networking ----------
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.prefix}-vnet"
  address_space       = [var.vnet_cidr]
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "snet_aks" {
  name                 = "snet-aks"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_aks]
}

# ---------- Log Analytics ----------
resource "azurerm_log_analytics_workspace" "law" {
  name                = "${var.prefix}-law"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# ---------- ACR ----------
resource "azurerm_container_registry" "acr" {
  name                = "${var.prefix}acr${random_string.sfx.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  sku                 = "Standard"
  admin_enabled       = false
}

# ---------- AKS ----------
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "${var.prefix}-aks"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "${var.prefix}-aks"

oidc_issuer_enabled         = true
workload_identity_enabled   = true

  sku_tier = "Free"

  default_node_pool {
    name                 = "system"
    vm_size              = var.aks_node_size
    node_count           = var.aks_node_count
    vnet_subnet_id       = azurerm_subnet.snet_aks.id
    type                 = "VirtualMachineScaleSets"
    orchestrator_version = null
  }

  identity {
    type = "SystemAssigned"
  }

  # Red avanzada
  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    load_balancer_sku = "standard"
    outbound_type     = "loadBalancer"
  }

  linux_profile {
    admin_username = var.admin_username
    ssh_key {
      key_data = chomp(file("~/.ssh/id_rsa.pub"))
    }
  }

  # Monitoring (Container Insights)
  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
  }

  role_based_access_control_enabled = true
  #workload_identity_enabled         = true

  lifecycle {
    ignore_changes = [default_node_pool[0].orchestrator_version]
  }
}

# Permitir que AKS lea imágenes de ACR
#resource "azurerm_role_assignment" "acr_pull" {
#  scope                = azurerm_container_registry.acr.id
#  role_definition_name = "AcrPull"
#  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
#}

#data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "kv" {
  name                       = "${var.prefix}-kv-${random_string.sfx.result}"
  resource_group_name        = azurerm_resource_group.rg.name
  location                   = var.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  purge_protection_enabled   = true
  soft_delete_retention_days = 14


  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get", "List", "Set", "Delete", "Purge", "Recover"
    ]
  }
}



resource "azurerm_key_vault_secret" "db" {
  name         = var.kv_secret_name
  value        = var.kv_secret_value
  key_vault_id = azurerm_key_vault.kv.id
}

# ---------- Private Endpoint para Key Vault ----------
resource "azurerm_private_dns_zone" "kv_privdns" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_endpoint" "kv_pe" {
  name                = "${var.prefix}-kv-pe"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.snet_aks.id

  private_service_connection {
    name                           = "kv-privlink"
    private_connection_resource_id = azurerm_key_vault.kv.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }
}

resource "azurerm_private_dns_zone_virtual_network_link" "kv_link" {
  name                  = "${var.prefix}-kv-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.kv_privdns.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}
