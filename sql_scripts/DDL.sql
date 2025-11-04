use jrm_sql_test;

-- sales overview table
drop table if exists sales_overview;

create table sales_overview as (
	select
		date_format(order_date, '%Y-%m-01') as ymd
		, product_name
		, country
		, state
		, category
		, subcategory
		, sum(unit_profit * quantity) as total_profit
		, sum(unit_price_USD * quantity) as total_revenue
		, count(distinct order_id) as total_orders
	from sales join products using(product_id)
		join stores using(store_id)
	group by country, state, category, subcategory, ymd, product_name
);


-- calendar table
drop table if exists calendar;

CREATE TABLE calendar (
    ymd DATE PRIMARY KEY,
    day INT,
    is_weekend BOOLEAN,
    month INT,
    month_name VARCHAR(20),
    week INT,
    weekday INT,
    weekday_name VARCHAR(20),
    year INT
);

set @@cte_max_recursion_depth = 10000;

INSERT INTO calendar (ymd, day, is_weekend, month, month_name, week, weekday, weekday_name, year)
WITH RECURSIVE dates AS (
    SELECT min(order_date) AS ymd
    from sales
    UNION ALL
    SELECT DATE_ADD(ymd, INTERVAL 1 DAY)
    FROM dates
    WHERE ymd < (select max(order_date) from sales)
)
SELECT 
    ymd,
    DAY(ymd) AS day,
    CASE WHEN DAYOFWEEK(ymd) IN (1,7) THEN TRUE ELSE FALSE END AS is_weekend,
    MONTH(ymd) AS month,
    MONTHNAME(ymd) AS month_name,
    WEEK(ymd, 3) AS week,       -- mode 3: Monday = 1, ISO 8601
    DAYOFWEEK(ymd) AS weekday,  -- Sunday = 1, Saturday = 7
    DAYNAME(ymd) AS weekday_name,
    YEAR(ymd) AS year
FROM dates;


select min(ymd), max(ymd) from calendar;