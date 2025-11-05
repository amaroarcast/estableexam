Steps:

Register providers: 
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.Network 
az provider register --namespace Microsoft.Compute
az provider register --namespace Microsoft.OperationalInsights
az provider register --namespace Microsoft.KeyVault

Generate a SSH key. 

terraform plan -out tfplan
terraform apply tfplan
