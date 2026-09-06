-- Put two tables back together: every order with the customer who placed it.
SET TIME ZONE 'Asia/Ho_Chi_Minh';

-- lesson: foundation.l1.sql-join
SELECT o.id AS order_id,
       c.full_name,
       o.status,
       o.placed_at
FROM orders AS o
INNER JOIN customers AS c ON c.id = o.customer_id
ORDER BY o.id;

-- Joining through a one-to-many multiplies rows: one line per item, not per
-- order. There are 12 orders but more order lines than that.
SELECT count(*) AS rows_after_joining_items
FROM orders AS o
INNER JOIN order_items AS i ON i.order_id = o.id;
