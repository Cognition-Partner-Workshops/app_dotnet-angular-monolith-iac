# Monolith Refactoring: Inventory Module Decomposition

This directory contains the code changes required to replace in-process Inventory module calls in the OrderManager monolith with HTTP calls to the new standalone `inventory-service` microservice.

## What Changed

The monolith's `InventoryManager` (in-process service) is replaced by `IInventoryServiceClient`, an HTTP client that calls the inventory-service REST API.

| Before (Monolith) | After (Refactored) |
|---|---|
| `InventoryManager` class with direct EF Core DB access | `IInventoryServiceClient` interface + `InventoryServiceClient` HTTP implementation |
| Shared SQLite database | Separate inventory-service with its own database |
| In-process method calls | HTTP REST calls over the cluster network |

## Files

| File | Purpose |
|---|---|
| `InventoryClient/IInventoryServiceClient.cs` | Interface matching the original `InventoryManager` API surface |
| `InventoryClient/InventoryItemDto.cs` | DTO for inventory items returned by the microservice |
| `InventoryClient/InventoryServiceClient.cs` | HTTP client implementation using `HttpClient` |
| `InventoryClient/ServiceCollectionExtensions.cs` | DI registration extension method |

## Integration Steps

### 1. Add the files to the monolith project

Copy the `InventoryClient/` directory into `src/OrderManager.Api/Clients/`.

### 2. Configure the service URL

Add to `appsettings.json`:

```json
{
  "InventoryService": {
    "BaseUrl": "http://inventory-service.decomposition-dev.svc.cluster.local"
  }
}
```

For local development, use:

```json
{
  "InventoryService": {
    "BaseUrl": "http://localhost:5001"
  }
}
```

### 3. Register in DI (Program.cs)

```csharp
// Remove: builder.Services.AddScoped<InventoryManager>();
// Add:
builder.Services.AddInventoryServiceClient(builder.Configuration);
```

### 4. Update controllers

Replace constructor injection of `InventoryManager` with `IInventoryServiceClient`:

```csharp
// Before
public InventoryController(InventoryManager inventoryManager) { ... }

// After
public InventoryController(IInventoryServiceClient inventoryClient) { ... }
```

### 5. Remove old Inventory module code

Once the HTTP client integration is verified, remove:
- `Models/InventoryItem.cs` (monolith copy)
- `Services/InventoryManager.cs` (monolith copy)
- `Data/` EF Core configuration for InventoryItems

### 6. Update Helm values

The monolith Helm chart needs an environment variable for the inventory service URL. This is already configured in the updated `helm/ordermanager/values-dev.yaml` and `values-staging.yaml`.
