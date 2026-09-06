-- Find the customers who never ordered anything. An INNER JOIN cannot answer
-- this question, because it drops exactly the rows you are looking for.
SET TIME ZONE 'Asia/Ho_Chi_Minh';

-- lesson: foundation.l1.sql-join
SELECT c.id, c.full_name, o.id AS order_id
FROM customers AS c
LEFT JOIN orders AS o ON o.customer_id = c.id
ORDER BY c.id, o.id;

SELECT c.id, c.full_name
FROM customers AS c
LEFT JOIN orders AS o ON o.customer_id = c.id
WHERE o.id IS NULL
ORDER BY c.id;
