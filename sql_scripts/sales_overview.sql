use jrm_sql_test;

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


select
	product_name
	, 1 - (unit_cost_USD / unit_price_USD)
	, sum(unit_profit * quantity) as total_profit
	, sum(unit_price_USD * quantity) as total_revenue
	, count(distinct order_id) as total_orders
from sales join products using(product_id)
group by product_name;