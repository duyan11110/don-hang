# Changelog

What changed in each version of Đơn Hàng, for the people who call its API or
use its app. Newest version first. The format follows Keep a Changelog, and
version numbers follow Semantic Versioning 2.0.0.

Each pull request that changes behaviour adds a line under Unreleased. A
release renames that section to the new version (see
`.github/workflows/release.yml`).

## [Unreleased]

## [1.0.0] - 2026-09-27

The first version with a declared public API: the OpenAPI document at
`/openapi/v1.json` describes it.

### Added

- Sign-in through Keycloak: clients get an access token with the
  authorization code flow and PKCE, and the API accepts Keycloak's tokens.
  Accounts have the role `customer` or `staff`.
- `PATCH /api/v1/orders/{id}/ship` marks an order as shipped (staff only).
- `PATCH /api/v1/products/{id}` changes a product's price (staff only).
- `GET /api/v1/products` takes `limit`, `offset` and `maxPriceVnd`.
- `POST /api/v1/orders` takes an optional `Idempotency-Key` header: a retry
  with the same key returns the order the first request created.
- `/api/v2/orders` (`POST`, `GET /{id}`): each item becomes a line with its
  own total, the order has a `totalVnd`, and `customerId` is gone.
  `/api/v1/orders` is unchanged.
- The OpenAPI document at `/openapi/v1.json`.
- `/health/live` and `/health/ready` on the API container.
- An email to the customer when an order is placed, cancelled or shipped,
  sent in the background and retried when the mail server fails.
- `/metrics` on the API container, including `donhang_orders_placed_total`.
- The app: sign-in through Keycloak, product and order detail pages with
  their own addresses, an order form that checks its fields and shows the
  API's error, English and Vietnamese, and a dark theme.
- Images `ghcr.io/duyan11110/donhang-api` and
  `ghcr.io/duyan11110/donhang-migrate`, tagged with the commit
  (`sha-<commit>`) and, for a release, with its version.

### Changed

- `GET /api/v1/products` returns at most 20 products unless `limit` asks
  for more (up to 100); it used to return every product.
- `GET /api/v1/orders` returns the caller's orders 20 at a time, after the
  order id given as `after`; it used to return all of them.
- `GET /api/v1/orders/{id}` now needs a signed-in caller, and only the
  order's customer or staff get it: anyone else gets `403`.
- A `409` for an order in the wrong status has a problem `type` for each
  case: `already-cancelled`, `already-shipped`, `not-paid`; two changes to
  the same order at once get `concurrent-update`.
- The database is migrated by a separate `migrate` container, which must
  finish before the API starts; the API no longer migrates when it starts.
- The API writes its logs as one JSON object per line.

### Removed

- `POST /api/v1/auth/login`. Get an access token from Keycloak instead and
  send it as before, in `Authorization: Bearer`.

### Fixed

- Cancelling an order that has already shipped answers `409`
  (`already-shipped`) instead of cancelling it.

## [0.1.0] - 2026-09-26

### Added

- An ASP.NET Core API behind Caddy: `POST /api/v1/auth/login` returns a
  token; `GET /api/v1/products`, `GET /api/v1/products/{id}`,
  `POST /api/v1/orders`, `GET /api/v1/orders`, `GET /api/v1/orders/{id}` and
  `PATCH /api/v1/orders/{id}/cancel`.
- Errors as problem details (`application/problem+json`).
- A Flutter web app: the product list, sign-in and placing an order.
- PostgreSQL with EF Core migrations.
