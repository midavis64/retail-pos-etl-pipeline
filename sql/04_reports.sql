-- 04_reports.sql
-- Builds daily summary and monthly profitability report.
-- (Pre-aggregation is the key optimization concept.)

-- rebuild daily summary (demo: full refresh)
TRUNCATE TABLE demo.daily_sales_summary;

INSERT INTO demo.daily_sales_summary(sale_date, product_id, total_qty, total_revenue)
SELECT
  sale_date,
  product_id,
  SUM(quantity) AS total_qty,
  SUM(revenue)  AS total_revenue
FROM demo.fact_pos_sales
WHERE product_id IS NOT NULL
GROUP BY sale_date, product_id;

-- build monthly profitability by store, incorporating store_expenses
TRUNCATE TABLE demo.monthly_profitability;

WITH monthly_sales AS (
  SELECT
    DATE_TRUNC('month', f.sale_date)::date AS month_start,
    f.store_id,
    SUM(f.revenue) AS revenue,
    SUM(f.quantity * p.unit_cost) AS cogs
  FROM demo.fact_pos_sales f
  JOIN demo.dim_product p ON p.product_id = f.product_id
  WHERE f.product_id IS NOT NULL
  GROUP BY 1, 2
),
monthly_expenses AS (
  SELECT
    DATE_TRUNC('month', expense_date)::date AS month_start,
    store_id,
    SUM(amount) AS expenses
  FROM demo.store_expenses
  GROUP BY 1, 2
)
INSERT INTO demo.monthly_profitability(month_start, store_id, revenue, cogs, expenses, profit)
SELECT
  s.month_start,
  s.store_id,
  ROUND(s.revenue::numeric, 2),
  ROUND(s.cogs::numeric, 2),
  ROUND(COALESCE(e.expenses, 0)::numeric, 2),
  ROUND((s.revenue - s.cogs - COALESCE(e.expenses, 0))::numeric, 2)
FROM monthly_sales s
LEFT JOIN monthly_expenses e
  ON e.month_start = s.month_start
 AND e.store_id = s.store_id
ORDER BY s.month_start, s.store_id;
