--Case 1 : Order Analysis
--Question 1 : 
--Please analyze the monthly distribution of orders. The order_approved_at data should be used for the date

SELECT
	(DATE_TRUNC('MONTH',o.approved_at))::DATE AS month,
	COUNT(1) AS order_qty
FROM orders o
WHERE approved_at IS NOT NULL
GROUP BY 1
ORDER BY 1
	
--Question 2 : 
--Please analyze the number of orders by order status on a monthly basis.

SELECT 
	TO_CHAR(o.approved_at,'YYYY-MM') AS month,
	order_status,
	COUNT(1) AS order_qty
FROM orders o
WHERE approved_at IS NOT NULL AND order_status='delivered'
GROUP BY 1,2
ORDER BY 1


--Question 3 : 
--Please analyze the number of orders by product category.

SELECT DISTINCT
	category_name,
	COUNT(1) AS order_qty
FROM order_items oi
LEFT JOIN products p on p.product_id=oi.product_id
LEFT JOIN orders o on o.order_id=oi.order_id
WHERE category_name IS NOT NULL AND approved_at IS NOT NULL
GROUP BY 1
ORDER BY 2 desc


--Question 4 : 
--Please analyze the number of orders based on the days of the week (Monday, Thursday, etc.) and the days of the month (1st, 2nd, etc.).
SELECT 
	TO_CHAR(approved_at, 'Day') AS day,
	EXTRACT(DAY FROM approved_at),
	COUNT(1)
FROM orders
WHERE approved_at IS NOT NULL 
GROUP BY 1,2
ORDER BY 3 DESC


--Case 2 : Customer Analysis
--Question 1 : 
--Which cities do customers shop in the most? Determine the customer's city with the highest number of orders and analyze accordingly.

WITH t1 AS
(
	SELECT DISTINCT
		unique_id,
		city,
		COUNT(*) OVER (PARTITION BY unique_id,city) city_order_count,
		COUNT(*) OVER (PARTITION BY unique_id) total_order_count
	FROM customers
	ORDER BY 1,2
),
t2 AS
(
	SELECT 
		unique_id,
		city,
		ROW_NUMBER() OVER (PARTITION BY unique_id ORDER BY city_order_count DESC) AS row	
	FROM t1
)

SELECT DISTINCT
	t2.unique_id,
	t2.city AS max_order_city,
	total_order_count
FROM t1
JOIN t2 ON t2.unique_id=t1.unique_id 
WHERE row=1
	
--Case 3: Seller Analysis
--Question 1 : 
--Who are the sellers who deliver orders to customers in the fastest way? Bring top 5. Examine the order numbers of these sellers and the comments and ratings on their products.

SELECT
	s.seller_id,
	AVG(AGE(delivered_customer,approved_at)) OVER(PARTITION BY s.seller_id) AS delivery_time,
	COUNT (o.order_id) OVER(PARTITION BY s.seller_id) AS order_qty,
	AVG (score) OVER(PARTITION BY s.seller_id) AS avg_score
FROM orders o
LEFT JOIN order_items oi on oi.order_id=o.order_id
LEFT JOIN sellers s on s.seller_id=oi.seller_id
LEFT JOIN reviews r on r.order_id = O.order_id
WHERE delivered_customer>approved_at AND order_status='delivered'
ORDER BY 2
LIMIT 5

 

WITH t1 AS
(
SELECT DISTINCT
	s.seller_id,
	AVG(EXTRACT(DAY FROM (AGE(delivered_customer,approved_at)))) OVER(PARTITION BY s.seller_id)::INT AS avg_delivery_time,
	COUNT (o.order_id) OVER(PARTITION BY s.seller_id) AS order_qty,
	ROUND(AVG (score) OVER(PARTITION BY s.seller_id),2) AS avg_score
FROM orders o
LEFT JOIN order_items oi on oi.order_id=o.order_id
LEFT JOIN sellers s on s.seller_id=oi.seller_id
LEFT JOIN reviews r on r.order_id = O.order_id
WHERE delivered_customer>approved_at AND order_status='delivered'
ORDER BY 2
LIMIT 1000
),

t2 AS
(
SELECT
	*,
	DENSE_RANK () OVER ( ORDER BY avg_delivery_time) AS seller_rank
FROM t1
WHERE order_qty>=36
)

SELECT 
	 *
FROM t2
WHERE seller_rank<6
ORDER BY seller_rank,order_qty DESC
 
--Question 2 : 
--Which sellers sell products from more categories? Do sellers with many categories also have a high number of orders?

WITH joined_table AS
(
	SELECT
		s.seller_id,
		order_id,
		category_name
	FROM order_items oi
	LEFT JOIN products p on p.product_id=oi.product_id
	LEFT JOIN sellers s on s.seller_id=oi.seller_id
),
sellers_rank AS
(
	SELECT 
		seller_id,
		COUNT(DISTINCT category_name) AS category_count,
		COUNT(DISTINCT order_id)  AS total_order,
		DENSE_RANK() OVER (ORDER BY COUNT(DISTINCT category_name) DESC) seller_category_rank
	FROM joined_table
	GROUP BY 1
	ORDER BY 3 DESC
)

SELECT*FROM sellers_rank 

--Case 4 : Payment Analysis
--Question 1 : 
--Which region do the users with the highest number of installments live in?

SELECT DISTINCT
	state,
	COUNT(installments) OVER(PARTITION BY state) AS installment_count,
	DENSE_RANK() OVER (ORDER BY gdp_per_capita DESC) AS gdp_rank,
	DENSE_RANK() OVER (ORDER BY population DESC) AS population_rank
FROM orders o
LEFT JOIN payments p on p.order_id=o.order_id
LEFT JOIN customers c on c.customer_id = o.customer_id
LEFT JOIN states s on s.state_id=c.state
WHERE installments IS NOT NULL AND type='credit_card' AND installments>=12
ORDER BY 2 DESC

--Question 2 : 
--Calculate the number of successful orders and total successful payment amount according to payment type. Rank them in order from the most used payment type to the least.

SELECT
	type,
	COUNT(DISTINCT o.order_id) AS delivered_order,
	CAST(SUM(value) AS INT) AS total_amount
FROM orders o
JOIN payments p on p.order_id=o.order_id
WHERE order_status!='unavailable' AND order_status!='cancalled' AND type IS NOT NULL
GROUP BY 1
ORDER BY 2 DESC
	
--Question 3 : 
--Make a category-based analysis of orders paid in one shot and in installments. In which categories is payment in installments used most?

WITH joined_table AS
(
	SELECT 
		category_name,
		oi.order_id,
		installments
	FROM order_items oi
	LEFT JOIN payments p on p.order_id=oi.order_id
	LEFT JOIN products pr on pr.product_id=oi.product_id
	WHERE category_name IS NOT NULL

),

installment_payment AS
(
	SELECT DISTINCT
		category_name,
		COUNT(order_id) AS installment_payment_orders
	FROM joined_table
	WHERE installments>1
	GROUP BY 1
	ORDER BY 2 DESC
),

single_payment AS
(
	SELECT DISTINCT
		category_name,
		COUNT(order_id) single_payment_orders
	FROM joined_table
	WHERE installments=1
	GROUP BY 1
	ORDER BY 2 DESC
)
SELECT*FROM installment_payment
