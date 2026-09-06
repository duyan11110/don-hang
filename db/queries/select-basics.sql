-- Ask one table a question: choose columns, filter rows, sort, cut.
SET TIME ZONE 'Asia/Ho_Chi_Minh';

-- lesson: foundation.l1.sql-select
SELECT id, name, price_vnd
FROM products
WHERE price_vnd > 500000
ORDER BY price_vnd DESC
LIMIT 3;

-- The same query without ORDER BY may return any three of the matching rows.
SELECT id, name
FROM products
WHERE price_vnd > 500000
LIMIT 3;

-- NULL means "unknown", so nothing is ever equal to it, not even NULL itself.
SELECT NULL = NULL AS "null_equals_null",
       NULL IS NULL AS "null_is_null";
