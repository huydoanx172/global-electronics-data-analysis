-- Analyze the total profit each month of each year based on unit USD; Note: Profit of one products = unit_price - unit_cost
select
	YEAR(s.order_date) as year
	, MONTH(s.order_date) as month
	, sum((p.unit_price_USD - p.unit_cost_USD) * s.quantity) as total_profit
from sales s inner join products p on s.product_id = p.product_id
group by year, month
order by year, month;

CREATE TABLE monthly_profits as (
	select
	YEAR(s.order_date) as year
	, MONTH(s.order_date) as month
	, sum((p.unit_price_USD - p.unit_cost_USD) * s.quantity) as total_profit
	from sales s inner join products p on s.product_id = p.product_id
	group by year, month
	order by year, month
);

-- Write a SQL query to see customer demographics meaning with format table
-- Age_Group, Gender, Country, State, Count_Customer
-- With Age_Group is
-- 0-17, 18-25, 26,35, 36-45, 46-55, 56+

with user_age as (
	select
		customer_id
		, timestampdiff(YEAR, birthday, current_date()) AS age
		, gender
		, country 
		, state
	from customers
)

create table user_demographics_counts as (
	select
	case when age >= 56 then '56+'
		when age >= 46 then '46-55'
		when age >= 36 then '36-45'
		when age >= 26 then '26-35'
		when age >= 18 then '18-25'
		else '0-17'
	end as age_group
	, gender
	, country
	, state
	, count(customer_id) as num_users
from (select
		customer_id
		, timestampdiff(YEAR, birthday, current_date()) AS age
		, gender
		, country 
		, state
	from customers) as user_age
group by gender, country, state, age_group
);

select
	case when age >= 56 then '56+'
		when age >= 46 then '46-55'
		when age >= 36 then '36-45'
		when age >= 26 then '26-35'
		when age >= 18 then '18-25'
		else '0-17'
	end as age_group
	, gender
	, country
	, state
	, count(customer_id) as num_users
from user_age
group by gender, country, state, age_group


-- Write a SQL query to determine the months where the month-over-month growth in cumulative profit is significant (at least 10%).
-- Based on unit USD

-- my way, easier to plot in BI program
with monthly_sales as (
	select date_format(s.order_date, "%Y-%m-01") as month
		, sum((p.unit_price_USD - p.unit_cost_USD) * s.quantity) as total_profit
	from sales s inner join products p on s.product_id = p.product_id
	group by date_format(s.order_date, "%Y-%m-01")
)
, cumulative_monthly_sales as (
	select month
		, sum(total_profit) over(order by month) as cumulative_profit
	from monthly_sales
)
, add_growth_pct as (
	select month
		, cumulative_profit
		, ROUND(cumulative_profit / lag(cumulative_profit) over(order by month) * 100 - 100, 0) as growth_MoM
	from cumulative_monthly_sales
)

select * from add_growth_pct where growth_MoM >= 10 order by month;

CREATE TABLE high_growth_months AS
SELECT *
FROM (
  WITH monthly_sales AS (
    SELECT 
      DATE_FORMAT(s.order_date, '%Y-%m-01') AS month,
      SUM((p.unit_price_USD - p.unit_cost_USD) * s.quantity) AS total_profit
    FROM sales s
    INNER JOIN products p ON s.product_id = p.product_id
    GROUP BY DATE_FORMAT(s.order_date, '%Y-%m-01')
  ),
  cumulative_monthly_sales AS (
    SELECT 
      month,
      SUM(total_profit) OVER (ORDER BY month) AS cumulative_profit
    FROM monthly_sales
  ),
  add_growth_pct AS (
    SELECT 
      month,
      cumulative_profit,
      ROUND(cumulative_profit / LAG(cumulative_profit) OVER (ORDER BY month) * 100 - 100, 0) AS growth_MoM
    FROM cumulative_monthly_sales
  )
  SELECT *
  FROM add_growth_pct
  WHERE growth_MoM >= 10
  ORDER BY month
) AS derived;


-- TODO: analyse actual sales growth not cumulative sales growth (doesnt mean much in the first months or last months)


-- Write a SQL query to find pairs of different Subcategories that are purchased together in the same order. 
-- Only include unique pairs (e.g., "Desktops" and "Movie DVD", not both "Desktops"-"Movie DVD" and "Movie DVD"-"Desktops").
with pairs_appearances as (
	select s1.order_id
		, s1.product_id as product_id_1
		, s2.product_id as product_id_2
	from sales s1 inner join sales s2 using(order_id)
	where s1.product_id > s2.product_id
)

, add_count_pairs as (
	select
		p2.subcategory as subcategory_1
		, p3.subcategory as subcategory_2
		, count(*) as num_appearances_together
	from pairs_appearances p1 inner join products p2 on p1.product_id_1 = p2.product_id
		inner join products p3 on p1.product_id_2 = p3.product_id
	group by subcategory_1, subcategory_2
)

select
	subcategory_1
	, subcategory_2
	, num_appearances_together
	, rank() over(order by num_appearances_together DESC) as rank_pair
from add_count_pairs


-- Create report of the top 2 selling products in each country, 
-- category, product name and ranking them accordingly.
with sales_by_category_country as (
	select
		max(category) as category
		, country
		, max(product_name) as product_name -- so that I only need to group by product_id -> faster runtime
		, sum((p.unit_price_USD - p.unit_cost_USD) * s.quantity) as total_profit
		, rank() over(partition by country order by sum((p.unit_price_USD - p.unit_cost_USD) * s.quantity) desc) as product_rank
	from sales s inner join products p on s.product_id = p.product_id
		inner join customers using(customer_id)
	group by country, s.product_id
)

select
	category
	, country
	, product_name
	, product_rank
from sales_by_category_country s1
where product_rank <= 2

/*
Analyse the profitability efficiency of each store by calculating:

Sample table:
StoreKey, Country, State, Square_Meters, TotalProfitLocalCurrency, ProfitPerSquareMeter, and Ranking.
*/
SELECT
	max(st.store_id) as store_id
	, max(st.country) as country
	, max(st.state) as state
	, max(st.square_meters) as square_meters
	, round(sum((p.unit_price_USD - p.unit_cost_USD) * s.quantity * e.exchange_rate), 0) as total_profit_local_currency
	, round(sum((p.unit_price_USD - p.unit_cost_USD) * s.quantity * e.exchange_rate) / max(st.square_meters), 0) as profit_per_square_meter
	, rank() over(order by sum((p.unit_price_USD - p.unit_cost_USD) * s.quantity * e.exchange_rate) / max(st.square_meters) desc) as rank_store
from sales s inner join products p using(product_id)
	inner join exchange_rates e on s.order_date = e.date
	inner join stores st using(store_id)
group by st.store_id
limit 10;

/*

Top 2 products by each country, ranked by local currency
*/
with sales_by_category_country as (
	select
		max(category) as category
		, country
		, max(product_name) as product_name -- so that I only need to group by product_id -> faster runtime
		, sum((p.unit_price_USD - p.unit_cost_USD) * s.quantity * e.exchange_rate) as total_profit
		, rank() over(partition by country order by sum((p.unit_price_USD - p.unit_cost_USD) * s.quantity) desc) as product_rank
	from sales s inner join products p on s.product_id = p.product_id
		inner join customers using(customer_id)
		inner join exchange_rates e on s.order_date = e.date
	group by country, s.product_id
)

select
	category
	, country
	, product_name
	, product_rank
from sales_by_category_country s1
where product_rank <= 2

/*
Total quantity purchased by each customer
*/
-- DECLARE @TargetOrderDate DATE = '2016-01-01';

SELECT
    c.customer_id,
    max(c.name) as name,
    max(c.city) as city,
    max(c.state) as state,
    max(c.Country) as country,
    COUNT(DISTINCT s.order_id) AS total_orders,
    SUM(s.quantity) AS total_quantity,
    MIN(s.order_date) AS first_order_date,
    MAX(s.delivery_date) AS last_delivery_date
FROM
    Customers c
JOIN
    Sales s ON c.customer_id = s.customer_id
-- WHERE
--     s.order_date = @TargetOrderDate
GROUP BY
    c.customer_id
ORDER BY
    Total_Quantity DESC;

/*
Calculate total number of orders by each country for each year
Format table
Country, Year 1, Year 2, Year 3,...
*/
-- select distinct YEAR(order_date) from sales;

select
	c.country
	, count(distinct case when YEAR(order_date) = 2016 then order_id end) as num_orders_2016
	, count(distinct case when YEAR(order_date) = 2017 then order_id end) as num_orders_2017
	, count(distinct case when YEAR(order_date) = 2018 then order_id end) as num_orders_2018
	, count(distinct case when YEAR(order_date) = 2019 then order_id end) as num_orders_2019
	, count(distinct case when YEAR(order_date) = 2020 then order_id end) as num_orders_2020
	, count(distinct case when YEAR(order_date) = 2021 then order_id end) as num_orders_2021
from sales s inner join customers c using(customer_id)
group by c.country;

-- Using Dynamic SQL so that it's easier to maintain
-- Step 1: Generate dynamic columns
SELECT GROUP_CONCAT(DISTINCT
        CONCAT(
            'COUNT(DISTINCT CASE WHEN YEAR(order_date) = ', YEAR(order_date),
            ' THEN order_id END) AS `num_orders_', YEAR(order_date), '`'
        )
    ) INTO @cols
FROM sales;

-- Step 2: Build dynamic SQL
SET @sql = CONCAT(
    'SELECT c.country, ', @cols, '
     FROM sales s
     INNER JOIN customers c USING(customer_id)
     GROUP BY c.country
     ORDER BY c.country;'
);

-- Step 3: Execute
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

