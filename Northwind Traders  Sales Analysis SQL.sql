--1-Ürün Analizi
--a)Her bir kategorinin en karlı ürününü bulunuz. 
WITH product_category_revenue AS (
    SELECT
        p.product_name,
        category_name,
        ROUND(SUM(od.unit_price * od.quantity * (1 - od.discount)) :: NUMERIC,2) AS total_revenue
    FROM products p
    JOIN order_details od ON p.product_id = od.product_id
    JOIN categories c ON c.category_id = p.category_id
   GROUP BY 1,2
),
ranked_products AS (
    SELECT
        product_name,
        category_name,
        total_revenue,
        ROW_NUMBER() OVER (PARTITION BY category_name ORDER BY total_revenue DESC) AS rank
    FROM product_category_revenue
)
SELECT
    product_name,
    category_name,
    total_revenue
FROM ranked_products
WHERE rank = 1;

--2-Shipping Analizi
--a)Teslimatı en hızlı sağlanan ilk 10 ülkeyi bulunuz. Bu ülkelerin net kazanç içindeki oranlarına bakınız.
WITH country_delivery_times AS (
    SELECT
        c.country,
        AVG(EXTRACT(DAY FROM (o.shipped_date::timestamp - o.order_date::timestamp))) AS avg_delivery_time 
    FROM orders o
    JOIN shippers s ON o.ship_via = s.shipper_id
    JOIN customers c ON o.customer_id = c.customer_id
    GROUP BY 1
    ORDER BY 2
    LIMIT 10
),
total_revenue AS (
    SELECT
        c.country,
        ROUND(SUM(od.unit_price * od.quantity * (1 - od.discount)) :: NUMERIC,2) AS total_revenue
    FROM orders o
    JOIN order_details od ON o.order_id = od.order_id
    JOIN customers c ON o.customer_id = c.customer_id
    GROUP BY 1
)
SELECT
    cdr.country,
    ROUND(cdr.avg_delivery_time::numeric, 2) AS avg_delivery_time, 
    tr.total_revenue,
    ROUND((tr.total_revenue / (SELECT SUM(total_revenue) FROM total_revenue))::numeric * 100, 2) AS revenue_percentage
FROM country_delivery_times cdr
JOIN total_revenue tr ON cdr.country = tr.country
ORDER BY 2

--b)Gecikmiş siparişleri firma ve ay bazında ayrı ayrı inceleyiniz.
SELECT
	s.company_name AS shipper_name,
	COUNT(1) AS delayed_order_count
FROM orders o
LEFT JOIN shippers s ON s.shipper_id = o.ship_via
WHERE o.required_date < o.shipped_date 
GROUP BY 1
ORDER BY 2 DESC

SELECT
	TO_CHAR(order_date, 'MM') AS order_month,
	COUNT(1) AS delayed_order_count
FROM orders
WHERE required_date < shipped_date 
GROUP BY 1
ORDER BY 2 DESC

--3-Çalışan Analizi
--a)Çalışanların sipariş başına ortalama getirilerini hesaplayınız.
SELECT 
    e.first_name || ' ' || e.last_name AS employee_name,
    COUNT(o.order_id) AS total_orders,
    ROUND(AVG(od.unit_price * od.quantity * (1 - od.discount)) ::NUMERIC ,2) AS avg_revenue_per_order
FROM employees e
JOIN orders o ON e.employee_id = o.employee_id
JOIN order_details od ON o.order_id = od.order_id
GROUP BY 1
ORDER BY 3 DESC;

--4-Müşteri Analizi
--a)Her bir müşterinin, siparişlerinin toplam tutarının geçen yıla göre değişim oranını hesaplayınız.
WITH customer_spending AS 
(
    SELECT
        c.customer_id,
        c.company_name,
        c.country,
		EXTRACT(YEAR FROM o.order_date) AS order_year,
        (SELECT MAX(EXTRACT(YEAR FROM order_date)) FROM orders) AS current_year,
        (SELECT MAX(EXTRACT(YEAR FROM order_date)) FROM orders) - 1 AS last_year,
		SUM(od.unit_price * od.quantity * (1 - od.discount)) AS total_spent
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
	JOIN order_details od ON o.order_id = od.order_id
	GROUP BY 1,2,3,4,5,6
),

spending_by_year AS
(
SELECT
    company_name,
    country,
    COALESCE(SUM(CASE WHEN order_year = current_year THEN total_spent END), 0) AS current_year_spending,
    COALESCE(SUM(CASE WHEN order_year = last_year THEN total_spent END), 0) AS last_year_spending
FROM customer_spending
GROUP BY 1,2
),
compared_spending AS
(
SELECT
	company_name,
    country,
	CASE 
       WHEN COALESCE(last_year_spending, 0) = 0 THEN 100
       ELSE ((current_year_spending - last_year_spending) / NULLIF(last_year_spending, 0) * 100)
    END AS spending_increase_percentage
FROM spending_by_year
)

SELECT*FROM compared_spending
ORDER BY 3 DESC


--b)Harcaması geçtiğimiz yıla göre artan-azalan ilk-son 5 müşterinin isim, artış-azalış miktarı ve ülkesini getiriniz.

SELECT
    *
FROM 
(
    SELECT
        ROW_NUMBER() OVER (ORDER BY spending_increase_percentage DESC) AS row_num,
        company_name,
        country,
		ROUND((spending_increase_percentage :: NUMERIC),2) AS spending_increase_percentage
    FROM compared_spending
) AS ranked_with_count
WHERE row_num <= 5 OR row_num > (SELECT COUNT(1) FROM compared_spending) - 5;
