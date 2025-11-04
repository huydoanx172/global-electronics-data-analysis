-- cohort analysis
use jrm_sql_test;

select * from sales;

select * from customers;

select count() from customers;

select
	date_format(order_date, '%Y-%m-01') as ymd
	, count(distinct customer_id) as num_unique_customers
from sales inner join customers using(customer_id)
group by ymd order by ymd;


create table cohort_analysis as (
	with customer_reg_dates as (
		select
			min(date_format(order_date, '%Y-%m-01')) as reg_date
			, customer_id
		from customers inner join sales using(customer_id)
		group by customer_id
	)
	
	, cohort_analysis as (select
		reg_date
		, date_format(order_date, '%Y-%m-01') as ymd
		, count(distinct customer_id) as num_active_customers
	from customer_reg_dates inner join sales using(customer_id)
	group by reg_date, ymd)
	
	, add_passed_month as (
		select *
			, timestampdiff(month, reg_date, ymd) as passed_month
		from cohort_analysis
	)
	
	select * from add_passed_month order by reg_date, ymd
);

-- user segment analysis (semileft, left, revival, dead, etc.)

select min(order_date), max(order_date) from sales;


-- Create date table
create table if not exists calendar (
    ymd date,
    year smallint,
    month tinyint,
    day tinyint,
    week int,
    weekday tinyint,
    month_name varchar(10),
    weekday_name varchar(10),
    is_weekend boolean
);

SET SESSION cte_max_recursion_depth = 10000;

insert into calendar
with recursive dates as (
    select date('2016-01-01') as ymd
    union all
    select date_add(ymd, interval 1 day)
    from dates
    where ymd < current_date()
)
select
    ymd,
    year(ymd),
    month(ymd),
    day(ymd),
    week(ymd, 3), -- ISO week number
    weekday(ymd), -- 0 = Monday
    monthname(ymd),
    dayname(ymd),
    case when dayofweek(ymd) in (1,7) then true else false end
from dates;




-- rankup analysis

-- active rate by rank, gender, country
