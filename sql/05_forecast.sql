-- 05_forecast.sql
-- Short-horizon demand forecast using 7-day moving average.
TRUNCATE TABLE demo.demand_forecast_7d_ma;

WITH daily_qty AS (
  SELECT
    sale_date,
    product_id,
    f.store_id,
    SUM(f.quantity) AS total_qty
  FROM demo.fact_pos_sales f
  WHERE f.product_id IS NOT NULL
  GROUP BY sale_date, product_id, f.store_id
),
ma AS (
  SELECT
    product_id,
    store_id,
    sale_date AS as_of_date,
    AVG(total_qty) OVER (
      PARTITION BY product_id, store_id
      ORDER BY sale_date
      ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS moving_avg_qty
  FROM daily_qty
)
INSERT INTO demo.demand_forecast_7d_ma(product_id, store_id, as_of_date, window_days, moving_avg_qty)
SELECT
  product_id,
  store_id,
  as_of_date,
  7,
  ROUND(moving_avg_qty::numeric, 3)
FROM ma
ORDER BY store_id, product_id, as_of_date;
