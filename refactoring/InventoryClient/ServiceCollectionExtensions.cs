using Microsoft.Extensions.DependencyInjection;

namespace OrderManager.Refactoring.InventoryClient;

public static class ServiceCollectionExtensions
{
    /// <summary>
    /// Registers the IInventoryServiceClient HTTP client with the DI container.
    /// Reads the base URL from configuration key "InventoryService:BaseUrl".
    ///
    /// Usage in Program.cs:
    ///   builder.Services.AddInventoryServiceClient(builder.Configuration);
    ///
    /// Required appsettings.json entry:
    ///   "InventoryService": { "BaseUrl": "http://inventory-service.decomposition-dev.svc.cluster.local" }
    /// </summary>
    public static IServiceCollection AddInventoryServiceClient(
        this IServiceCollection services,
        Microsoft.Extensions.Configuration.IConfiguration configuration)
    {
        services.AddHttpClient<IInventoryServiceClient, InventoryServiceClient>(client =>
        {
            var baseUrl = configuration["InventoryService:BaseUrl"]
                ?? throw new InvalidOperationException(
                    "InventoryService:BaseUrl is not configured. Add it to appsettings.json.");
            client.BaseAddress = new Uri(baseUrl);
            client.Timeout = TimeSpan.FromSeconds(30);
            client.DefaultRequestHeaders.Add("Accept", "application/json");
        });

        return services;
    }
}
