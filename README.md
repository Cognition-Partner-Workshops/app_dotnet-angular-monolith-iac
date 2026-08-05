# app_dotnet-angular-monolith-iac
Service-specific IaC for the OrderManager monolith. Azure delivery via Bicep (Azure Container Apps) and a GitHub Actions pipeline that builds and pushes to Azure Container Registry.

Delivery was migrated from AWS (ECR + EKS/ArgoCD Helm + Terraform + Secrets Manager) to Azure (ACR + Azure Container Apps + Bicep + Key Vault). See [`bicep/README.md`](bicep/README.md) for the full mapping and deploy instructions. Application code is unchanged.
