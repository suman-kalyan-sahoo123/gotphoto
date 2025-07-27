with date_spine as (
  select date_column
  from (
    select 
      dateadd(day, seq4(), '1990-01-01'::date) as date_column
    from table(generator(rowcount => 10000))
  )
  where date_column <= '2030-12-31'::date
),

date_attributes as (
  select
    date_column as date_key,
    date_column as full_date,
    year(date_column) as year,
    month(date_column) as month,
    day(date_column) as day,
    dayofweek(date_column) as day_of_week,
    dayofyear(date_column) as day_of_year,
    weekofyear(date_column) as week_of_year,
    quarter(date_column) as quarter,
    case 
      when dayofweek(date_column) in (1, 7) then 'Weekend'
      else 'Weekday'
    end as day_type,
    case 
      when month(date_column) in (12, 1, 2) then 'Winter'
      when month(date_column) in (3, 4, 5) then 'Spring'
      when month(date_column) in (6, 7, 8) then 'Summer'
      when month(date_column) in (9, 10, 11) then 'Fall'
    end as season,
    case 
      when month(date_column) = 1 then 'January'
      when month(date_column) = 2 then 'February'
      when month(date_column) = 3 then 'March'
      when month(date_column) = 4 then 'April'
      when month(date_column) = 5 then 'May'
      when month(date_column) = 6 then 'June'
      when month(date_column) = 7 then 'July'
      when month(date_column) = 8 then 'August'
      when month(date_column) = 9 then 'September'
      when month(date_column) = 10 then 'October'
      when month(date_column) = 11 then 'November'
      when month(date_column) = 12 then 'December'
    end as month_name,
    case 
      when dayofweek(date_column) = 1 then 'Sunday'
      when dayofweek(date_column) = 2 then 'Monday'
      when dayofweek(date_column) = 3 then 'Tuesday'
      when dayofweek(date_column) = 4 then 'Wednesday'
      when dayofweek(date_column) = 5 then 'Thursday'
      when dayofweek(date_column) = 6 then 'Friday'
      when dayofweek(date_column) = 7 then 'Saturday'
    end as day_name,
    case 
      when quarter(date_column) = 1 then 'Q1'
      when quarter(date_column) = 2 then 'Q2'
      when quarter(date_column) = 3 then 'Q3'
      when quarter(date_column) = 4 then 'Q4'
    end as quarter_name,
    concat(year, '-', lpad(month, 2, '0')) as year_month,
    concat(year, '-Q', quarter) as year_quarter,
    case 
      when month(date_column) = 1 and day(date_column) = 1 then true
      else false
    end as is_new_year,
    case 
      when month(date_column) = 12 and day(date_column) = 31 then true
      else false
    end as is_year_end,
    case 
      when day(date_column) = 1 then true
      else false
    end as is_month_start,
    case 
      when day(date_column) = day(last_day(date_column)) then true
      else false
    end as is_month_end
  from date_spine
)

select
  date_key,
  full_date,
  year,
  month,
  day,
  day_of_week,
  day_of_year,
  week_of_year,
  quarter,
  day_type,
  season,
  month_name,
  day_name,
  quarter_name,
  year_month,
  year_quarter,
  is_new_year,
  is_year_end,
  is_month_start,
  is_month_end
from date_attributes 