# Retail POS ETL (PostgreSQL + Docker)

A portfolio project that simulates a retail operations ETL + validation + reporting workflow.

## Repo layout

```
retail-pos-etl/
  docker-compose.yml
  run_nightly.sh
  exports/                   # generated CSV outputs
  sql/
    00_schema.sql
    01_load_staging.sql
    02_transform.sql
    03_validations.sql
    04_reports.sql
    05_forecast.sql
  data/
    pos_exports/
      pos_2024-01-01.csv
      pos_2024-01-02.csv
      ...
    product_catalog.csv
    store_expenses.csv
```

## What it does
- Loads product catalog + store expenses + a daily POS export
- Normalizes SKUs, deduplicates by transaction_id, and loads a fact table
- Runs validation checks and writes findings to `demo.etl_exceptions`
- Builds monthly profitability (revenue, COGS, expenses, profit)
- Builds a 7-day moving average demand forecast per product + store
- Exports CSV artifacts into `./exports/`

## Prerequisites
- Docker Desktop (or Docker Engine) running

## Run the nightly pipeline
```bash
chmod +x run_nightly.sh
./run_nightly.sh
```

Run a specific POS export:
```bash
./run_nightly.sh data/pos_exports/pos_2024-01-10.csv
```

## DBeaver connection
- Host: localhost
- Port: 5432
- Database: retail_demo
- Username: analyst
- Password: analyst

Schema: `demo`
