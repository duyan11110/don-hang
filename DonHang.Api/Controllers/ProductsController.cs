using System.ComponentModel.DataAnnotations;
using DonHang.Domain;
using DonHang.Infrastructure;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace DonHang.Api.Controllers;

// lesson: backend.l1.rest-resources
// The list reads DonHangDbContext directly: it has no rule to apply, only a
// query to shape. One product at a time goes through IProductRepository.
[ApiController]
[Route("api/v1/products")]
public sealed class ProductsController(DonHangDbContext db, IProductRepository products) : ControllerBase
{
    private const int MaxPageSize = 100;

    // lesson: backend.l2.offset-pagination
    // GET /api/v1/products?limit=20&offset=40. A `limit` outside 1..100 is
    // refused with 400, so no request can ask for the whole table at once.
    // Sorting by the unique id keeps every page in the same, fixed order.
    [HttpGet]
    public async Task<ActionResult<List<ProductDto>>> List(
        [FromQuery, Range(1, MaxPageSize)] int limit = 20,
        [FromQuery, Range(0, int.MaxValue)] int offset = 0,
        [FromQuery] int? maxPriceVnd = null)
    {
        IQueryable<Product> query = db.Products;

        // lesson: backend.l2.filtering-with-query-parameters
        // Added to the query before it runs, so PostgreSQL filters, not C#.
        if (maxPriceVnd is not null)
        {
            query = query.Where(p => p.PriceVnd <= maxPriceVnd);
        }

        var page = await query
            .OrderBy(p => p.Id)
            .Skip(offset)
            .Take(limit)
            .Select(p => new ProductDto(p.Id, p.Name, p.PriceVnd))
            .ToListAsync();
        return Ok(page);
    }

    // lesson: backend.l1.get-and-status-codes
    [HttpGet("{id:int}")]
    public async Task<ActionResult<ProductDto>> Get(int id)
    {
        var product = await products.FindAsync(id);
        if (product is null) return NotFound();
        return Ok(new ProductDto(product.Id, product.Name, product.PriceVnd));
    }
}
