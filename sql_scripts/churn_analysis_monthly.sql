-- customer segment analysis monthly
use jrm_sql_test;

with months_customer_list as (
	select ymd, customer_id
	from
		(select distinct date(date_format(ymd, "%Y-%m-01")) as ymd from calendar) as ymd
			cross join (select distinct customer_id from customers) as customer_id
	where timestampdiff(month, ymd, '2021-02-01') <= 3 and timestampdiff(month, ymd, '2021-02-01') >= 0
)

, monthly_sales_record as (
	select
		date(date_format(order_date, "%Y-%m-01")) as ymd
		, customer_id
		, sum(unit_profit * quantity) as total_profit
		, sum(unit_price_USD * quantity) as total_revenue
		, sum(quantity) as total_quantity
	from sales inner join products using(product_id)
	group by customer_id, ymd
)

, every_month_customers_purchases as (
	select 
		a.ymd
		, a.customer_id
		, sum(b.total_profit) over(partition by a.customer_id) as total_profit
		, sum(b.total_quantity) over(partition by a.customer_id) as total_quantity
		, coalesce(b.total_quantity, 0) as quantity
	from months_customer_list a left join monthly_sales_record b using(ymd, customer_id)
)

, first_buy_dates as (
	select
		customer_id
		, min(order_date) as first_buy_date
	from sales
	group by customer_id
)

-- defining segments:
-- 		- continuous user: buy continuously every month for >= 3 months
--      - new user: first purchase is this month
--      - recurring customer: purchase 2 months in a row
--      - churned customer: last buy date >= 3 months ago
--      - revival customer: bought this month, and hasn't bought for >= 3 months before that.


, add_buying_flags as (
	select
		*
		, if(quantity > 0, 1, 0) as bought_this_month_flag
		, if(lag(quantity, 1) over(partition by customer_id order by ymd) > 0, 1, 0) as bought_1_month_flag
		, if(lag(quantity, 2) over(partition by customer_id order by ymd) > 0, 1, 0) as bought_2_month_flag
		, if(lag(quantity, 3) over(partition by customer_id order by ymd) > 0, 1, 0) as bought_3_month_flag
	from every_month_customers_purchases
)

, add_first_buy_dates as (
	select a.*
		, b.first_buy_date
	from add_buying_flags a inner join first_buy_dates b using(customer_id)
	where ymd = '2021-2-1' -- only getting the most recent records
)

, categorise_customers as (
	select
		customer_id
		, total_profit
		, total_quantity
		, case
			when bought_this_month_flag and date_format(first_buy_date, '%Y-%m-01') = '2021-02-01' then 'new_customer'
			when (bought_this_month_flag) and not (bought_1_month_flag or bought_2_month_flag or bought_3_month_flag) then 'revived_customer'
			when bought_this_month_flag + bought_1_month_flag + bought_2_month_flag + bought_3_month_flag >= 2 then 'recurring_customer'
			when bought_this_month_flag or bought_1_month_flag or bought_2_month_flag or bought_3_month_flag then 'recent_customer'
			
			else 'churned_customer' end as customer_type
	from add_first_buy_dates
)

select
	customer_type
	, sum(total_profit) as total_profit
	, count(*) as num_customers
from categorise_customers
group by customer_type;

-- turn all the above code into a table
create table churn_analysis as (
	with months_customer_list as (
		select ymd, customer_id
		from
			(select distinct date(date_format(ymd, "%Y-%m-01")) as ymd from calendar) as ymd
				cross join (select distinct customer_id from customers) as customer_id
		where timestampdiff(month, ymd, '2021-02-01') <= 3 and timestampdiff(month, ymd, '2021-02-01') >= 0
	)
	
	, monthly_sales_record as (
		select
			date(date_format(order_date, "%Y-%m-01")) as ymd
			, customer_id
			, sum(unit_profit * quantity) as total_profit
			, sum(unit_price_USD * quantity) as total_revenue
			, sum(quantity) as total_quantity
		from sales inner join products using(product_id)
		group by customer_id, ymd
	)
	
	, every_month_customers_purchases as (
		select 
			a.ymd
			, a.customer_id
			, sum(b.total_profit) over(partition by a.customer_id) as total_profit
			, sum(b.total_quantity) over(partition by a.customer_id) as total_quantity
			, coalesce(b.total_quantity, 0) as quantity
		from months_customer_list a left join monthly_sales_record b using(ymd, customer_id)
	)
	
	, first_buy_dates as (
		select
			customer_id
			, min(order_date) as first_buy_date
		from sales
		group by customer_id
	)
	
	, add_buying_flags as (
		select
			*
			, if(quantity > 0, 1, 0) as bought_this_month_flag
			, if(lag(quantity, 1) over(partition by customer_id order by ymd) > 0, 1, 0) as bought_1_month_flag
			, if(lag(quantity, 2) over(partition by customer_id order by ymd) > 0, 1, 0) as bought_2_month_flag
			, if(lag(quantity, 3) over(partition by customer_id order by ymd) > 0, 1, 0) as bought_3_month_flag
		from every_month_customers_purchases
	)
	
	, add_first_buy_dates as (
		select a.*
			, b.first_buy_date
		from add_buying_flags a inner join first_buy_dates b using(customer_id)
		where ymd = '2021-2-1' -- only getting the most recent records
	)
	
	, categorise_customers as (
		select
			customer_id
			, total_profit
			, total_quantity
			, case
				when bought_this_month_flag and date_format(first_buy_date, '%Y-%m-01') = '2021-02-01' then 'new_customer'
				when (bought_this_month_flag) and not (bought_1_month_flag or bought_2_month_flag or bought_3_month_flag) then 'revived_customer'
				when bought_this_month_flag + bought_1_month_flag + bought_2_month_flag + bought_3_month_flag >= 2 then 'recurring_customer'
				when bought_this_month_flag or bought_1_month_flag or bought_2_month_flag or bought_3_month_flag then 'recent_customer'
				
				else 'churned_customer' end as customer_type
		from add_first_buy_dates
	)
	
	select
		customer_type
		, sum(total_profit) as total_profit
		, count(*) as num_customers
	from categorise_customers
	group by customer_type
);

-- now add the proportions of cumulative revenue they consist of. So that my power bi matrix looks pretty.
-- also analyse proportion of revenue this month
-- JUST DO REVENUE DONT THINK ABOUT ANY OTHER METRICS

-- oh then if you want a 2d matrix you will have to separate them into paying segments, like high payers low payers etc.
-- get IQR ranges
with total_spend as (
	select customer_id
		, sum(quantity * unit_price_USD) as total_revenue
	from sales join products using(product_id)
	group by customer_id
)

, add_ranking as (
	select customer_id
		, total_revenue
		, row_number() over(order by total_revenue) as order_num
		, count(*) over() as total_count
	from total_spend
)

, quartiles as (
	select
		max(case when order_num = floor(total_count * 0.01) then total_revenue end) as Q1
		, max(case when order_num = floor(total_count * 0.99) then total_revenue end) as Q3
	from add_ranking
)

select * from quartiles;
-- 1136 and 6424.59 0.25 and 0.75
-- 848.97 and 7493.61 for 20 and 80
-- 357.95 and 11051.65 for 10 and 90
-- 158.76 and 14887.34 for 5 and 95
-- 24.99 and 24.962.43 for 1 and 99
-- seems like a power law here.

