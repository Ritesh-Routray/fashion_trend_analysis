SELECT 'products'           AS table_name, COUNT(*) AS row_count FROM products
UNION ALL
SELECT 'trend_signals',                    COUNT(*) FROM trend_signals
UNION ALL
SELECT 'inventory',                        COUNT(*) FROM inventory
UNION ALL
SELECT 'sales_transactions',               COUNT(*) FROM sales_transactions
UNION ALL
SELECT 'purchase_orders',                  COUNT(*) FROM purchase_orders
UNION ALL
SELECT 'social_signals',                   COUNT(*) FROM social_signals
UNION ALL
SELECT 'trend_sku_mapping',                COUNT(*) FROM trend_sku_mapping
ORDER BY table_name;