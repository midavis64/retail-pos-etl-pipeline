#!/usr/bin/env bash
set -euo pipefail

POS_FILE="${1:-}"
if [[ -z "${POS_FILE}" ]]; then
  POS_FILE="$(ls -1t data/pos_exports/*.csv | head -n 1)"
fi

if [[ ! -f "${POS_FILE}" ]]; then
  echo "POS export not found: ${POS_FILE}"
  exit 1
fi

PRODUCT_FILE="data/product_catalog.csv"
EXPENSE_FILE="data/store_expenses.csv"

if [[ ! -f "${PRODUCT_FILE}" ]]; then
  echo "Product catalog not found: ${PRODUCT_FILE}"
  exit 1
fi

if [[ ! -f "${EXPENSE_FILE}" ]]; then
  echo "Store expenses not found: ${EXPENSE_FILE}"
  exit 1
fi

docker compose up -d

echo "Waiting for database..."
for i in {1..40}; do
  if docker exec retail_demo_pg pg_isready -U analyst -d retail_demo >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

POS_BASENAME="$(basename "${POS_FILE}" .csv)"
POS_IN_CONTAINER="/data/pos_exports/${POS_BASENAME}.csv"
PRODUCT_IN_CONTAINER="/data/product_catalog.csv"
EXPENSE_IN_CONTAINER="/data/store_expenses.csv"

echo "Resetting pipeline tables..."
docker exec -i retail_demo_pg psql \
  -U analyst \
  -d retail_demo \
  -v ON_ERROR_STOP=1 \
  -f - < sql/01_load_staging.sql

echo "Loading dim_product..."
docker exec -i retail_demo_pg psql -U analyst -d retail_demo -v ON_ERROR_STOP=1 -c \
"\\copy demo.dim_product(product_id, sku, product_name, category, supplier, unit_cost)
 FROM '${PRODUCT_IN_CONTAINER}'
 WITH (FORMAT csv, HEADER true);"

docker exec -i retail_demo_pg psql -U analyst -d retail_demo -v ON_ERROR_STOP=1 -c \
"UPDATE demo.dim_product
 SET sku = UPPER(TRIM(sku));"

echo "Loading store_expenses..."
docker exec -i retail_demo_pg psql -U analyst -d retail_demo -v ON_ERROR_STOP=1 -c \
"\\copy demo.store_expenses(expense_id, store_id, expense_date, expense_type, amount)
 FROM '${EXPENSE_IN_CONTAINER}'
 WITH (FORMAT csv, HEADER true);"

echo "Loading staging POS export..."
docker exec -i retail_demo_pg psql -U analyst -d retail_demo -v ON_ERROR_STOP=1 -c \
"\\copy demo.staging_pos_sales_raw(transaction_id, store_id, sku, sale_ts, quantity, unit_price)
 FROM '${POS_IN_CONTAINER}'
 WITH (FORMAT csv, HEADER true);"

echo "Transform..."
docker exec -i retail_demo_pg psql \
  -U analyst \
  -d retail_demo \
  -v ON_ERROR_STOP=1 \
  -f - < sql/02_transform.sql

echo "Validations..."
docker exec -i retail_demo_pg psql \
  -U analyst \
  -d retail_demo \
  -v ON_ERROR_STOP=1 \
  -f - < sql/03_validations.sql

echo "Reports..."
docker exec -i retail_demo_pg psql \
  -U analyst \
  -d retail_demo \
  -v ON_ERROR_STOP=1 \
  -f - < sql/04_reports.sql

echo "Forecast..."
docker exec -i retail_demo_pg psql \
  -U analyst \
  -d retail_demo \
  -v ON_ERROR_STOP=1 \
  -f - < sql/05_forecast.sql

echo "Exporting outputs..."
docker exec -i retail_demo_pg psql -U analyst -d retail_demo -v ON_ERROR_STOP=1 -c \
"\\copy (
  SELECT *
  FROM demo.etl_exceptions
  ORDER BY run_ts DESC, issue_type, transaction_id
) TO '/exports/${POS_BASENAME}_exceptions.csv'
 WITH (FORMAT csv, HEADER true);"

docker exec -i retail_demo_pg psql -U analyst -d retail_demo -v ON_ERROR_STOP=1 -c \
"\\copy (
  SELECT *
  FROM demo.monthly_profitability
  ORDER BY month_start, store_id
) TO '/exports/monthly_profitability.csv'
 WITH (FORMAT csv, HEADER true);"

docker exec -i retail_demo_pg psql -U analyst -d retail_demo -v ON_ERROR_STOP=1 -c \
"\\copy (
  SELECT *
  FROM demo.demand_forecast_7d_ma
  ORDER BY store_id, product_id, as_of_date
) TO '/exports/demand_forecast_7d_ma.csv'
 WITH (FORMAT csv, HEADER true);"

echo "Done."
echo "Outputs:"
echo "  exports/${POS_BASENAME}_exceptions.csv"
echo "  exports/monthly_profitability.csv"
echo "  exports/demand_forecast_7d_ma.csv"