# app/Modules

Business logic lives here, one folder per bounded module (Tech Spec §10):

```text
app/Modules/
├── Tenant
├── Auth
├── Catalog
├── Order
├── Payment
├── Shipping
├── Billing
├── Theme
├── Domain
├── Notification
├── Discount
├── Analytics
├── Return
└── Admin
```

Empty at Stage 0 — Tahap 1 adds the first modules (`Tenant`, `Auth`).

## Rules (non-negotiable, Tech Spec §10 / prompt-development.md §0)

```text
Controller
  ↓
Service / Use Case
  ↓
Repository
  ↓
Model / Database
```

- `Http/Controllers/` stays thin: routing + request validation only, no business logic (Tech Spec §10).
- A module may only reach into another module through its `Services/` — never import another module's `Models/` or `Providers/` directly.
- Provider-dependent integrations (payment gateways, shipping couriers) go through an interface/contract in `Contracts/`, with concrete implementations in `Providers/`. The `Order` module must depend only on `PaymentProviderInterface` / `ShippingProviderInterface`, never a specific SDK.
- This boundary is enforced by `tests/Arch/ModuleBoundaryTest.php` (`pest --group=arch`). The concrete per-module assertion is added once a second module exists to check a boundary between.

Each module gets its own `README.md` once created, documenting what it owns and its public `Services/` surface — `docs/CODEMAP.md` is generated from these.
