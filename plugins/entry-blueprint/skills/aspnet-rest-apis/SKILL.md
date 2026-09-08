---
name: aspnet-rest-apis
description: Enigmatry Entry Blueprint .NET 10 Web API patterns covering MediatR, Autofac, FluentValidation, and vertical slice architecture. Use this when adding or modifying .NET API features, handlers, validators, controllers, or the frontend validation configuration that goes with them.
---

# Blueprint .NET API Patterns

The `Users` and `Products` slices in the template are the reference implementations. The code below is based on them, trimmed and simplified: the real files have more fields, both classic and primary constructors, and a few quirks. When the host project still has them, read the real files first and use these excerpts for the shape.

There is **no AutoMapper**. Projections are hand-written `Select` extensions on `IQueryable<T>`.

## Feature folder structure

```
Api/Features/Products/
  GetProducts.cs                 // list query — static class
  GetProductDetails.cs           // detail query — static class
  IsProductCodeUnique.cs         // uniqueness query for the form
  ProductsController.cs          // thin — only mediator.Send()
Api/Features/Users/
  GetRoleLookup.cs               // lookup query for dropdowns
Api/Features/
  LookupRequest.cs, LookupResponse.cs, LookupItemExtensions.cs
Api/Features/Validations/
  ProductEditComponentValidationConfiguration.cs   // rules for the generated Angular form

Domain/Products/
  Product.cs                     // entity: constants, private setters, Create/Update
  ProductStatus.cs, ProductType.cs
  ProductQueryableExtensions.cs  // QueryByName, QueryByCode, ... used by handlers
  Commands/ProductCreateOrUpdate.cs               // static class: Command, Result, Validator
  Commands/ProductCreateOrUpdateCommandHandler.cs // separate file
  Commands/RemoveProduct.cs                       // small command: handler nested
  DomainEvents/ProductCreatedDomainEvent.cs

Infrastructure/Data/Configurations/ProductConfiguration.cs
Infrastructure/Autofac/Modules/*.cs
ApplicationServices/Auditing/AuditableDomainEventHandler.cs
CodeGeneration.Setup/Features/Products/Product{Edit,List}ComponentConfiguration.cs
```

## Queries — static class in Api/Features/

**Detail query.** Projection extension in the same static class, `SingleOrNotFoundAsync` so the controller returns 404:

```csharp
public static class GetProductDetails
{
    [PublicAPI]
    public class Request : IQuery<Response>
    {
        public Guid Id { get; set; }
    }

    [PublicAPI]
    public class Response
    {
        public Guid Id { get; set; }
        public string Name { get; set; } = String.Empty;
        public string Code { get; set; } = String.Empty;
        public ProductType Type { get; set; }
        public float Discount { get; set; }
    }

    [UsedImplicitly]
    public class RequestHandler(IRepository<Product> productRepository) : IRequestHandler<Request, Response>
    {
        public async Task<Response> Handle(Request request, CancellationToken cancellationToken)
        {
            var response = await productRepository.QueryAll()
                .QueryById(request.Id)
                .MapToProductDetailsItem()
                .SingleOrNotFoundAsync(cancellationToken);
            return response;
        }
    }

    public static IQueryable<Response> MapToProductDetailsItem(this IQueryable<Product> query) =>
        query.Select(x => new Response
        {
            Id = x.Id,
            Name = x.Name,
            Code = x.Code,
            Type = x.Type,
            Discount = x.Discount ?? 0
        });
}
```

**List query.** `PagedRequest` + `IPagedRequestHandler`; filters come from the domain's `QueryBy*` extensions, never inline `Where`:

```csharp
public static class GetProducts
{
    [PublicAPI]
    public class Request : PagedRequest<Response.Item>, IQuery<PagedResponse<Response.Item>>
    {
        public string? Name { get; set; }
        public string? Code { get; set; }
        public DateOnly? ExpiresBefore { get; set; }
    }

    [PublicAPI]
    public static class Response
    {
        [PublicAPI]
        public class Item
        {
            public Guid Id { get; set; }
            public string Name { get; set; } = String.Empty;
            public string Code { get; set; } = String.Empty;
        }
    }

    [UsedImplicitly]
    public class RequestHandler(IRepository<Product> productRepository) : IPagedRequestHandler<Request, Response.Item>
    {
        public async Task<PagedResponse<Response.Item>> Handle(Request request, CancellationToken cancellationToken) =>
            await productRepository.QueryAll()
                .QueryByCode(request.Code)
                .QueryByName(request.Name)
                .QueryExpiresBefore(request.ExpiresBefore)
                .MapToProductItem()
                .ToPagedResponseAsync(request, cancellationToken);
    }

    public static IQueryable<Response.Item> MapToProductItem(this IQueryable<Product> query) =>
        query.Select(x => new Response.Item { Id = x.Id, Name = x.Name, Code = x.Code });
}
```

**Uniqueness query** (backs the async validator on the Angular form; exclude the record being edited):

```csharp
public static class IsProductCodeUnique
{
    [PublicAPI]
    public class Request : IQuery<Response>
    {
        public Guid? Id { get; set; }
        public string Code { get; set; } = String.Empty;
    }

    [PublicAPI]
    public class Response
    {
        public bool IsUnique { get; set; }
    }

    [UsedImplicitly]
    public class RequestHandler(IRepository<Product> productRepository) : IRequestHandler<Request, Response>
    {
        public async Task<Response> Handle(Request request, CancellationToken cancellationToken)
        {
            var isUnique = !await productRepository.QueryAll()
                .Where(x => x.Id != request.Id)
                .AnyAsync(x => x.Code == request.Code, cancellationToken);
            return new Response { IsUnique = isUnique };
        }
    }
}
```

**Lookup query** for dropdowns. The entity implements `ILookupItem<TId>` (`Id`, `Name`); `LookupRequest<T>`, `LookupResponse<T>` and `MapToLookup()` already exist in `Api/Features/`:

```csharp
public static class GetRoleLookup
{
    [PublicAPI]
    public class Request : LookupRequest<Guid>;

    [UsedImplicitly]
    public class RequestHandler(IRepository<Role> roleRepository)
        : IRequestHandler<Request, IEnumerable<LookupResponse<Guid>>>
    {
        public async Task<IEnumerable<LookupResponse<Guid>>> Handle(Request request, CancellationToken cancellationToken) =>
            await roleRepository.QueryAll().MapToLookup().OrderBy(r => r.Label).ToListAsync(cancellationToken);
    }
}
```

## Query filters — `IQueryable` extensions in Domain

One extension per filter; `null` or empty means "no filter". The template uses the C# 14 `extension` block:

```csharp
public static class ProductQueryableExtensions
{
    extension(IQueryable<Product> query)
    {
        public IQueryable<Product> QueryByName(string? name) =>
            name is null or "" ? query : query.Where(e => e.Name.Contains(name));

        public IQueryable<Product> QueryExpiresBefore(DateOnly? expiresBefore) =>
            expiresBefore is not null ? query.Where(e => e.ExpiresOn <= expiresBefore) : query;

        public IQueryable<Product> QueryInStatus(ProductStatus status) =>
            query.Where(e => e.Status == status);

        // nullable column: guard the null, or CS8602 fails the build
        public IQueryable<Product> QueryByManufacturer(string? manufacturer) =>
            manufacturer is null or "" ? query : query.Where(e => e.Manufacturer != null && e.Manufacturer.Contains(manufacturer));
    }
}
```

## Commands — static class in Domain/{Feature}/Commands/

`Command`, `Result` and `Validator` nested. Validators may inject a repository for cross-record rules (synchronous `.Any()` / `.Sum()` inside `Must`); the uniqueness rule below is illustrative, the template's validator has code-prefix and storage-capacity rules instead. Limits are constants on the entity so the validator, the EF configuration and the frontend validation configuration share them:

```csharp
public static class ProductCreateOrUpdate
{
    [PublicAPI]
    public class Command : IRequest<Result>
    {
        public Guid? Id { get; set; }
        public string Name { get; set; } = String.Empty;
        public string Code { get; set; } = String.Empty;
        public ProductType Type { get; set; }
        public DateOnly? ExpiresOn { get; set; }
        public bool HasDiscount { get; set; }
        public float? Discount { get; set; }
    }

    [PublicAPI]
    public class Result
    {
        public Guid Id { get; set; }
    }

    [UsedImplicitly]
    public class Validator : AbstractValidator<Command>
    {
        private readonly IRepository<Product> _productRepository;

        public Validator(IRepository<Product> productRepository)
        {
            _productRepository = productRepository;

            RuleFor(x => x.Name).NotEmpty().MaximumLength(Product.NameMaxLength);
            RuleFor(x => x.Code).NotEmpty().Must(BeUniqueCode).WithMessage("Code is already taken");
            When(x => x.Type is ProductType.Food or ProductType.Drink, () =>
            {
                RuleFor(x => x.ExpiresOn).NotNull();
            });
            When(x => x.HasDiscount, () =>
            {
                RuleFor(x => x.Discount).NotNull()
                    .GreaterThanOrEqualTo(Product.DiscountMinValue)
                    .LessThanOrEqualTo(Product.DiscountMaxValue);
            });
        }

        private bool BeUniqueCode(Command command, string code) =>
            !_productRepository.QueryAll().Where(x => x.Id != command.Id).Any(x => x.Code == code);
    }
}
```

The **create/update handler** is a separate `*CommandHandler.cs` in the same folder:

```csharp
[UsedImplicitly]
public class ProductCreateOrUpdateCommandHandler(IRepository<Product> productRepository)
    : IRequestHandler<ProductCreateOrUpdate.Command, ProductCreateOrUpdate.Result>
{
    public async Task<ProductCreateOrUpdate.Result> Handle(ProductCreateOrUpdate.Command request, CancellationToken cancellationToken)
    {
        Product result;
        if (request.Id.HasValue)
        {
            result = await productRepository.FindByIdAsync(request.Id.Value)
                     ?? throw new InvalidOperationException("Could not find product by Id");
            result.Update(request);
        }
        else
        {
            result = Product.Create(request);
            productRepository.Add(result);
        }

        return new ProductCreateOrUpdate.Result { Id = result.Id };
    }
}
```

A **small command** keeps its handler nested (`RemoveProduct`):

```csharp
public static class RemoveProduct
{
    [PublicAPI]
    public class Command : IRequest
    {
        public Guid Id { get; set; }
    }

    [UsedImplicitly]
    public class RequestHandler(IRepository<Product> repository) : IRequestHandler<Command>
    {
        public async Task Handle(Command request, CancellationToken cancellationToken)
        {
            var product = await repository.FindByIdAsync(request.Id) ?? throw new InvalidOperationException("Product could not be found");
            repository.Delete(product);
        }
    }
}
```

Handlers and validators need **no registration**: MediatR scans the assemblies, and `AppAddFluentValidation()` registers every validator in the Domain, ApplicationServices and Api assemblies.

## Domain entities

Inherit `EntityWithCreatedUpdated`, private setters, constants for limits, static `Create(Command)`, `Update(Command)`, domain events via `AddDomainEvent()`:

```csharp
public class Product : EntityWithCreatedUpdated
{
    public const int NameMaxLength = 50;
    public const int CodeMaxLength = 12;
    public const float DiscountMinValue = 0.0F;
    public const float DiscountMaxValue = 100.0F;

    public string Name { get; private set; } = String.Empty;
    public string Code { get; private set; } = String.Empty;
    public ProductType Type { get; private set; } = ProductType.Food;
    public ProductStatus Status { get; private set; } = ProductStatus.Active;
    public bool HasDiscount { get; private set; }
    public float? Discount { get; private set; }

    public static Product Create(ProductCreateOrUpdate.Command request)
    {
        var product = new Product
        {
            Name = request.Name,
            Code = request.Code,
            Type = request.Type,
            HasDiscount = request.HasDiscount,
            Discount = request.Discount,
            Status = ProductStatus.Active
        };
        product.AddDomainEvent(new ProductCreatedDomainEvent(product));
        return product;
    }

    public void Update(ProductCreateOrUpdate.Command request)
    {
        Name = request.Name;
        Code = request.Code;
        Type = request.Type;
        HasDiscount = request.HasDiscount;
        Discount = HasDiscount ? request.Discount : null;
        AddDomainEvent(new ProductUpdatedDomainEvent(this));
    }
}
```

## Domain events

Events are records deriving from `AuditableDomainEvent(eventName)` in `Domain/{Feature}/DomainEvents/`, with an `AuditPayload`. A generic `INotificationHandler<T>` in `ApplicationServices/Auditing/` logs every `AuditableDomainEvent`; a feature-specific reaction is another `[UsedImplicitly] INotificationHandler<TEvent>` in ApplicationServices:

```csharp
public record ProductCreatedDomainEvent : AuditableDomainEvent
{
    public ProductCreatedDomainEvent(Product product) : base("ProductCreated")
    {
        Name = product.Name;
        Code = product.Code;
    }

    public string Name { get; }
    public string Code { get; }

    public override object AuditPayload => new { Name, Code };
}
```

## Controllers — always thin

```csharp
[Produces(MediaTypeNames.Application.Json)]
[Route("api/[controller]")]
public class ProductsController(IMediator mediator) : Controller
{
    [HttpGet]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [UserHasPermission(PermissionId.ProductsRead)]
    public async Task<ActionResult<PagedResponse<GetProducts.Response.Item>>> Search([FromQuery] GetProducts.Request query)
    {
        var response = await mediator.Send(query);
        return response.ToActionResult();
    }

    [HttpGet]
    [Route("{id:guid}")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [UserHasPermission(PermissionId.ProductsRead)]
    public async Task<ActionResult<GetProductDetails.Response>> Get(Guid id)
    {
        var response = await mediator.Send(new GetProductDetails.Request { Id = id });
        return response.ToActionResult();
    }

    [HttpGet]
    [Route("code-unique")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [UserHasPermission(PermissionId.ProductsRead)]
    public async Task<ActionResult<IsProductCodeUnique.Response>> IsCodeUnique([FromQuery] IsProductCodeUnique.Request request)
    {
        var response = await mediator.Send(request);
        return response.ToActionResult();
    }

    [HttpPost]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ValidationProblemDetails), StatusCodes.Status400BadRequest)]
    [UserHasPermission(PermissionId.ProductsWrite)]
    public async Task<ActionResult<ProductCreateOrUpdate.Result>> Post(ProductCreateOrUpdate.Command command)
    {
        var result = await mediator.Send(command);
        return result;
    }

    [HttpDelete]
    [Route("{id:guid}")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [UserHasPermission(PermissionId.ProductsDelete)]
    public async Task Remove(Guid id) => await mediator.Send(new RemoveProduct.Command { Id = id });
}
```

- Primary-constructor injection of `IMediator`.
- Queries return `response.ToActionResult()` (maps not-found to 404); commands return the result directly.
- Lookups are extra `[HttpGet]` routes on the feature controller (`[Route("roles")]` on `UsersController`).
- Every endpoint has `[UserHasPermission(PermissionId.X)]`; add new permissions to `PermissionId`.

## EF Core configurations — Infrastructure/Data/Configurations/

```csharp
public class ProductConfiguration : IEntityTypeConfiguration<Product>
{
    public void Configure(EntityTypeBuilder<Product> builder)
    {
        builder.Property(x => x.Name).IsRequired().HasMaxLength(Product.NameMaxLength);
        builder.Property(x => x.Code).IsRequired().HasMaxLength(Product.CodeMaxLength);
        builder.Property(x => x.Status).HasSentinel(ProductStatus.Active).HasDefaultValue(ProductStatus.Active);
        builder.HasCreatedByAndUpdatedBy();
        builder.HasIndex(x => x.Code).IsUnique();
    }
}
```

Schema changes need a migration: `scripts/add-migration.ps1`, or `dotnet-ef migrations add <Name>` with the `Data.Migrations` project as both `--project` and `--startup-project` and `--context AppDbContext`.

## Frontend validation configuration — Api/Features/Validations/

The generated Angular form gets its client-side rules from a `ValidationConfiguration<TResponse>` over the **detail query's Response**. Mirror the FluentValidation rules with the same entity constants, then reference it from the edit component configuration in `CodeGeneration.Setup` via `builder.WithValidationConfiguration(new ProductEditComponentValidationConfiguration())`:

```csharp
public class ProductEditComponentValidationConfiguration : ValidationConfiguration<GetProductDetails.Response>
{
    public ProductEditComponentValidationConfiguration()
    {
        RuleFor(x => x.Name).IsRequired().MinLength(Product.NameMinLength).MaxLength(Product.NameMaxLength);
        RuleFor(x => x.Code).IsRequired();
        RuleFor(x => x.Type).IsRequired();
        RuleFor(x => x.Discount).GreaterOrEqualTo(Product.DiscountMinValue).LessOrEqualTo(Product.DiscountMaxValue);
    }
}
```

## Autofac modules — Infrastructure/Autofac/Modules/

Register services in Autofac modules, not via `IServiceCollection`:

```csharp
public class MyFeatureModule : Module
{
    protected override void Load(ContainerBuilder builder)
    {
        builder.RegisterType<MyService>().As<IMyService>().InstancePerLifetimeScope();
    }
}
```

Auto-registered, no module entry needed: classes named `*Service` (`ServiceModule`), classes named `*Repository` in Infrastructure (`EntityFrameworkModule`), MediatR handlers, FluentValidation validators.

## Adding a field to an existing feature — checklist

1. Entity: property with private setter, a `const` limit if bounded, set it in `Create` and `Update`.
2. Command: property; Validator: rule using the entity constant.
3. EF configuration (`HasMaxLength`, `IsRequired`) and a migration.
4. Detail and list Responses and their `MapTo*` projections. Add a `QueryBy*` extension if the list filters on it.
5. `*ValidationConfiguration` and the `CodeGeneration.Setup` edit/list component configuration; rebuild `CodeGeneration.Setup`, then `npm run codegen:run`.
6. `npm run nswag` with the API running, to regenerate the TypeScript client.
7. Snapshots: any `.verified.txt` that serializes the entity now differs. Grep the test projects for the entity name; in the template `Scheduler.Tests/CleanOldProductsJobFixture.*.verified.txt` serializes whole `Product` rows.
8. Tests: a `{Feature}ControllerFixture` in `Api.Tests/Features/` plus a `{Entity}Builder` in `Domain.Tests/{Feature}/`. The template ships these for Users only; for another feature copy `UsersControllerFixture` and `UserBuilder`. New Verify snapshots need one test run to produce the `.received.txt` you accept as `.verified.txt`; do not hand-write them. See `entry-blueprint:csharp-unit-tests`.
9. Frontend side of a filter (see `entry-blueprint:angular`): the `TextSearchFilter` in `features/{feature}/models/get-{feature}-query.model.ts`, the `client.search(...)` call in the list component, and translation keys in `src/i18n/messages.*.json` for the ids codegen emits (`{feature}.{feature}-edit.{field}.label`, `.placeholder`, `{feature}.{feature}-list.{field}`). The NSwag client passes query properties **positionally in `Request` property order**, so append new filter properties at the end of `Request` to keep existing calls valid.

## What NOT to do

- Do not put logic in controllers — use `IRequestHandler<T>`.
- Do not introduce AutoMapper or another mapping library — project with `Select` in a `MapTo*` extension.
- Do not filter inline in a handler when a `QueryBy*` extension fits — add one in `{Entity}QueryableExtensions`.
- Do not use `services.AddSingleton/Scoped` for services — use Autofac modules.
- Do not add `!` null-forgiving operators.
- Do not add null checks where the type system already guarantees a value — trust the nullable annotations. Check for `null` only at entry points: controller actions, queue/service-bus consumers, and deserialization or external-input boundaries. In-process MediatR handlers are not entry points.
- Do not use static `Log.Information(...)` — inject `ILogger<T>`.
- Do not create a command/query without a validator when it has user inputs.
- Do not add a command field without the matching `ValidationConfiguration` rule — the generated form will accept invalid input.
- Do not add `Version=` to a `<PackageReference>` in a `.csproj` — all versions go in `Directory.Packages.props`.
- Do not omit `[PublicAPI]` on request/response/DTO types or `[UsedImplicitly]` on handlers and validators.
