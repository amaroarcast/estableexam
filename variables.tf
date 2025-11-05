variable "prefix" {
  type    = string
  default = "estable"
}

variable "location" {
  type    = string
  default = "eastus"
}

variable "rg_name" {
  type    = string
  default = null
}

variable "aks_node_count" {
  type    = number
  default = 2
}

variable "aks_node_size" {
  type    = string
 # default = "Standard_DS3_v2"
 default = "Standard_D2s_v3"
}

variable "admin_username" {
  type    = string
  default = "azureuser"
}

# Red
variable "vnet_cidr" {
  type    = string
  default = "10.50.0.0/16"
}

variable "subnet_aks" {
  type    = string
  default = "10.50.1.0/24"
}

# Key Vault (ejemplo)
variable "kv_secret_name" {
  type    = string
  default = "db-connection-string"
}

variable "kv_secret_value" {
  type    = string
  default = "Server=tcp:db;User Id=app;Password=PASSdificil123*"
}

