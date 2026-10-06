using System.ComponentModel.DataAnnotations;
using DonHang.Catalog;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace DonHang.Api.Controllers;

// lesson: backend.l1.rest-resources
// lesson: design.l3.module-contracts
// From stage-3 every product request goes through ICatalog, the Catalog
// module's contract: this controller cannot see Product, Catalog's DbContext
// or its cache, so it cannot query `products` directly as it did at stage-2.
[ApiController]
[Route("api/v1/products")]
public sealed class ProductsController(ICatalog catalog) : ControllerBase
{
    private const int MaxPageSize = 100;

    // lesson: backend.l2.offset-pagination
    // GET /api/v1/products?limit=20&offset=40. A `limit` outside 1..100 is
    // refused with 400, so no request can ask for the whole table at once.
    [HttpGet]
    [EnableRateLimiting("catalog-reads")]
    public async Task<ActionResult<List<ProductDto>>> List(
        [FromQuery, Range(1, MaxPageSize)] int limit = 20,
        [FromQuery, Range(0, int.MaxValue)] int offset = 0,
        [FromQuery] int? maxPriceVnd = null)
    {
        var page = await catalog.ListAsync(limit, offset, maxPriceVnd);
        return Ok(page.Select(ToDto).ToList());
    }

    // lesson: backend.l1.get-and-status-codes
    // lesson: backend.l2.cache-aside
    // Catalog reads one product through its ProductCache, so a repeat of this
    // request within the TTL is answered from Redis.
    // lesson: backend.l3.bulkhead
    // Both product reads share the "catalog-reads" concurrency limit
    // (Program.cs): a read over it gets 503 at once. Orders do not count.
    [HttpGet("{id:int}")]
    [EnableRateLimiting("catalog-reads")]
    public async Task<ActionResult<ProductDto>> Get(int id)
    {
        var product = await catalog.FindAsync(id);
        if (product is null) return NotFound();
        return Ok(ToDto(product));
    }

    // lesson: backend.l2.cache-invalidation
    // PATCH /api/v1/products/3 {"priceVnd": 950000}, staff only. The cache
    // deletes product:3 after the new price is saved; this code does not
    // know there is a cache at all.
    [Authorize(Policy = "StaffOnly")]
    [HttpPatch("{id:int}")]
    public async Task<ActionResult<ProductDto>> UpdatePrice(int id, UpdateProductPriceRequest request)
    {
        var product = await catalog.ChangePriceAsync(id, request.PriceVnd);
        if (product is null) return NotFound();
        return Ok(ToDto(product));
    }

    private static ProductDto ToDto(CatalogProduct product) => new(product.Id, product.Name, product.PriceVnd);
}
