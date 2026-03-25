namespace OrderManager.Refactoring.InventoryClient;

public interface IInventoryServiceClient
{
    Task<List<InventoryItemDto>> GetAllInventoryAsync();
    Task<InventoryItemDto?> GetInventoryByProductIdAsync(int productId);
    Task<InventoryItemDto> RestockAsync(int productId, int quantity);
    Task<InventoryItemDto> DeductStockAsync(int productId, int quantity);
    Task<List<InventoryItemDto>> GetLowStockItemsAsync();
}
