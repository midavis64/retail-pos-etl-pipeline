# Canonical Requirements Spec (Demo)

## Sources
- POS exports (daily CSV)
- Product catalog (reference/master)
- Store expenses (for profitability)

## Join keys
- Normalize SKU: `UPPER(TRIM(sku))`
- Join POS → product: `sku_norm = dim_product.sku`

## Transformations
- Normalize SKU formatting
- Deduplicate by `transaction_id` (keep most recent `sale_ts`)
- Compute revenue
- Build monthly profitability (revenue - COGS - expenses)
- Build 7-day moving average forecast (per store/product)

## Acceptance tests
- No negative/zero quantities (or captured as exceptions)
- No negative unit prices (or captured as exceptions)
- Duplicate transaction_id in an export captured as exceptions
- Missing product references captured as exceptions
- Control totals: fact revenue ~= daily/monthly rollups
