-- 02_transform.sql
-- Cleans/normalizes data and upserts into the fact table.
-- Expected variables:
--  :run_id

WITH cleaned AS (
  SELECT
    transaction_id,
    store_id,
    UPPER(TRIM(sku)) AS sku_norm,
    sale_ts,
    (sale_ts::date) AS sale_date,
    quantity,
    unit_price,
    ROUND((quantity * unit_price)::numeric, 2) AS revenue,
    ROW_NUMBER() OVER (PARTITION BY transaction_id ORDER BY sale_ts DESC) AS rn
  FROM demo.staging_pos_sales_raw
  WHERE transaction_id IS NOT NULL
)
INSERT INTO demo.fact_pos_sales(transaction_id, store_id, product_id, sku_norm, sale_date, sale_ts, quantity, unit_price, revenue)
SELECT
  c.transaction_id,
  c.store_id,
  p.product_id,
  c.sku_norm,
  c.sale_date,
  c.sale_ts,
  c.quantity,
  c.unit_price,
  c.revenue
FROM cleaned c
LEFT JOIN demo.dim_product p
  ON p.sku = c.sku_norm
WHERE c.rn = 1
ON CONFLICT (transaction_id) DO UPDATE SET
  store_id  = EXCLUDED.store_id,
  product_id = EXCLUDED.product_id,
  sku_norm  = EXCLUDED.sku_norm,
  sale_date = EXCLUDED.sale_date,
  sale_ts   = EXCLUDED.sale_ts,
  quantity  = EXCLUDED.quantity,
  unit_price = EXCLUDED.unit_price,
  revenue   = EXCLUDED.revenue;
