# OrderManager Monolith-to-Microservices Decomposition Plan

## Current State: Monolith

The OrderManager application is a single .NET 8 + Angular 17 application with four tightly coupled modules:

| Module     | Responsibility                   | Database Tables        |
|-----------|----------------------------------|------------------------|
| Orders    | Order lifecycle management       | Orders, OrderItems     |
| Products  | Product catalog management       | Products               |
| Customers | Customer information management  | Customers              |
| Inventory | Stock tracking and alerts        | InventoryItems         |

All modules share a single SQLite database and are deployed as one unit.

## Target State: Microservices

Each module becomes an independent service conforming to the platform standard defined in `platform-engineering-shared-services`:

```
order-service       -> ECR: workshop/order-service
product-service     -> ECR: workshop/product-service
customer-service    -> ECR: workshop/customer-service
inventory-service   -> ECR: workshop/inventory-service
api-gateway         -> ECR: workshop/api-gateway
web-frontend        -> ECR: workshop/web-frontend
```

## Platform Conformance Requirements

Each extracted microservice must:

1. **Have its own Helm chart** following the template in this repo
2. **Include an ArgoCD Application manifest** for GitOps deployment
3. **Deploy to the correct namespace** (`decomposition-dev` or `decomposition-staging`)
4. **Conform to network policies** — only accept traffic from ingress-nginx and monitoring namespaces
5. **Expose Prometheus metrics** via ServiceMonitor
6. **Use ECR** for container image storage
7. **Include health check endpoints** (`/health`)
8. **Have its own database** (no shared database)

## Decomposition Order

1. **Product Service** — least coupled, read-heavy
2. **Customer Service** — minimal dependencies
3. **Inventory Service** — depends on Product (event-driven)
4. **Order Service** — depends on all others (API composition)
5. **API Gateway** — aggregates services for frontend
6. **Web Frontend** — Angular SPA calling API Gateway

## IaC Repository Structure

```
app_dotnet-angular-monolith-iac/
  helm/ordermanager/        # Monolith Helm chart (initial)
  docker/Dockerfile          # Multi-stage build
  argocd/                    # ArgoCD application manifests
  ci/                        # GitHub Actions pipelines
  docs/                      # This documentation
```

As services are extracted, new Helm charts and ArgoCD manifests are added to this repo.
