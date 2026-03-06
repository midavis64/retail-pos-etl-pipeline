-- 01_load_staging.sql

TRUNCATE TABLE
  demo.demand_forecast_7d_ma,
  demo.daily_sales_summary,
  demo.monthly_profitability,
  demo.fact_pos_sales,
  demo.staging_pos_sales_raw,
  demo.store_expenses,
  demo.dim_product
CASCADE;