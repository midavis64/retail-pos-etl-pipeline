-- 03_validations.sql (DBeaver: single shared run_id)

WITH run AS (
  SELECT gen_random_uuid() AS run_id
),

ins_invalid_qty AS (
  INSERT INTO demo.etl_exceptions(run_id, issue_type, transaction_id, store_id, sku, sale_ts, detail)
  SELECT
    (SELECT run_id FROM run),
    'invalid_quantity',
    transaction_id,
    store_id,
    sku,
    sale_ts,
    'quantity <= 0'
  FROM demo.staging_pos_sales_raw
  WHERE quantity IS NULL OR quantity <= 0
  RETURNING 1
),

ins_invalid_price AS (
  INSERT INTO demo.etl_exceptions(run_id, issue_type, transaction_id, store_id, sku, sale_ts, detail)
  SELECT
    (SELECT run_id FROM run),
    'invalid_unit_price',
    transaction_id,
    store_id,
    sku,
    sale_ts,
    'unit_price < 0'
  FROM demo.staging_pos_sales_raw
  WHERE unit_price IS NULL OR unit_price < 0
  RETURNING 1
),

ins_dupes AS (
  INSERT INTO demo.etl_exceptions(run_id, issue_type, transaction_id, store_id, sku, sale_ts, detail)
  SELECT
    (SELECT run_id FROM run),
    'duplicate_transaction_id_in_export',
    s.transaction_id,
    MIN(s.store_id),
    MIN(s.sku),
    MIN(s.sale_ts),
    'transaction_id appears multiple times in the same export'
  FROM demo.staging_pos_sales_raw s
  WHERE s.transaction_id IS NOT NULL
  GROUP BY s.transaction_id
  HAVING COUNT(*) > 1
  RETURNING 1
),

ins_missing_product AS (
  INSERT INTO demo.etl_exceptions(run_id, issue_type, transaction_id, store_id, sku, sale_ts, detail)
  SELECT
    (SELECT run_id FROM run),
    'missing_product_reference',
    f.transaction_id,
    f.store_id,
    f.sku_norm,
    f.sale_ts,
    'SKU not found in dim_product'
  FROM demo.fact_pos_sales f
  WHERE f.product_id IS NULL
    AND f.sale_ts::date IN (
      SELECT DISTINCT sale_ts::date
      FROM demo.staging_pos_sales_raw
    )
  RETURNING 1
)

SELECT
  (SELECT run_id FROM run) AS run_id,
  (SELECT COUNT(*) FROM ins_invalid_qty) AS invalid_quantity_rows,
  (SELECT COUNT(*) FROM ins_invalid_price) AS invalid_unit_price_rows,
  (SELECT COUNT(*) FROM ins_dupes) AS duplicate_transaction_rows,
  (SELECT COUNT(*) FROM ins_missing_product) AS missing_product_reference_rows;