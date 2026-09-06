-- Turn rows into numbers: how much has each customer actually paid?
SET TIME ZONE 'Asia/Ho_Chi_Minh';

-- lesson: foundation.l1.sql-group-by
SELECT c.id,
       c.full_name,
       count(*)      AS rows_in_group,
       count(p.id)   AS payments_made,
       coalesce(sum(p.amount_vnd), 0) AS paid_vnd
FROM customers AS c
LEFT JOIN orders AS o   ON o.customer_id = c.id
LEFT JOIN payments AS p ON p.order_id = o.id
GROUP BY c.id, c.full_name
ORDER BY paid_vnd DESC, c.id;

-- WHERE filters rows before grouping; HAVING filters the groups afterwards.
SELECT c.full_name, sum(p.amount_vnd) AS paid_vnd
FROM customers AS c
INNER JOIN orders AS o   ON o.customer_id = c.id
INNER JOIN payments AS p ON p.order_id = o.id
WHERE p.method = 'card'
GROUP BY c.full_name
HAVING sum(p.amount_vnd) > 2000000
ORDER BY paid_vnd DESC;
