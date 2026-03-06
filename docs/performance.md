# Performance Notes

This demo includes the typical pattern used to speed up recurring reports:
- Create indexes on commonly filtered/joined columns
- Pre-aggregate into smaller summary tables (daily rollups) and generate monthly reports from those

Indexes created in `sql/00_schema.sql`:
- `demo.fact_pos_sales(sale_date)`
- `demo.fact_pos_sales(store_id, sale_date)`
- `demo.fact_pos_sales(product_id, sale_date)`
