-- 00_schema.sql
CREATE SCHEMA IF NOT EXISTS demo;

CREATE TABLE IF NOT EXISTS demo.dim_product (
  product_id   TEXT PRIMARY KEY,
  sku          TEXT UNIQUE NOT NULL,
  product_name TEXT NOT NULL,
  category     TEXT NOT NULL,
  supplier     TEXT NOT NULL,
  unit_cost    NUMERIC(10,2) NOT NULL CHECK (unit_cost >= 0)
);

CREATE TABLE IF NOT EXISTS demo.store_expenses (
  expense_id   TEXT PRIMARY KEY,
  store_id     TEXT NOT NULL,
  expense_date DATE NOT NULL,
  expense_type TEXT NOT NULL,
  amount       NUMERIC(12,2) NOT NULL CHECK (amount >= 0)
);

CREATE TABLE IF NOT EXISTS demo.staging_pos_sales_raw (
  transaction_id TEXT,
  store_id       TEXT,
  sku            TEXT,
  sale_ts        TIMESTAMP,
  quantity       INTEGER,
  unit_price     NUMERIC(10,2)
);

CREATE TABLE IF NOT EXISTS demo.fact_pos_sales (
  transaction_id TEXT PRIMARY KEY,
  store_id       TEXT NOT NULL,
  product_id     TEXT NULL REFERENCES demo.dim_product(product_id),
  sku_norm       TEXT NOT NULL,
  sale_date      DATE NOT NULL,
  sale_ts        TIMESTAMP NOT NULL,
  quantity       INTEGER NOT NULL,
  unit_price     NUMERIC(10,2) NOT NULL,
  revenue        NUMERIC(12,2) NOT NULL
);

CREATE TABLE IF NOT EXISTS demo.etl_exceptions (
  run_id      UUID NOT NULL,
  run_ts      TIMESTAMPTZ NOT NULL DEFAULT now(),
  issue_type  TEXT NOT NULL,
  transaction_id TEXT NULL,
  store_id    TEXT NULL,
  sku         TEXT NULL,
  sale_ts     TIMESTAMP NULL,
  detail      TEXT NULL
);

CREATE TABLE IF NOT EXISTS demo.daily_sales_summary (
  sale_date     DATE NOT NULL,
  product_id    TEXT NOT NULL REFERENCES demo.dim_product(product_id),
  total_qty     INTEGER NOT NULL,
  total_revenue NUMERIC(12,2) NOT NULL,
  PRIMARY KEY (sale_date, product_id)
);

CREATE TABLE IF NOT EXISTS demo.monthly_profitability (
  month_start  DATE NOT NULL,
  store_id     TEXT NOT NULL,
  revenue      NUMERIC(14,2) NOT NULL,
  cogs         NUMERIC(14,2) NOT NULL,
  expenses     NUMERIC(14,2) NOT NULL,
  profit       NUMERIC(14,2) NOT NULL,
  generated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (month_start, store_id)
);

CREATE TABLE IF NOT EXISTS demo.demand_forecast_7d_ma (
  product_id     TEXT NOT NULL REFERENCES demo.dim_product(product_id),
  store_id       TEXT NOT NULL,
  as_of_date     DATE NOT NULL,
  window_days    INTEGER NOT NULL DEFAULT 7,
  moving_avg_qty NUMERIC(12,3) NOT NULL,
  generated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (product_id, store_id, as_of_date)
);

-- Indexes (part of optimization story)
CREATE INDEX IF NOT EXISTS idx_fact_sale_date ON demo.fact_pos_sales(sale_date);
CREATE INDEX IF NOT EXISTS idx_fact_store_date ON demo.fact_pos_sales(store_id, sale_date);
CREATE INDEX IF NOT EXISTS idx_fact_product_date ON demo.fact_pos_sales(product_id, sale_date);
CREATE INDEX IF NOT EXISTS idx_expenses_store_date ON demo.store_expenses(store_id, expense_date);
