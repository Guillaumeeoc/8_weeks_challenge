# Context

Data Mart is Danny’s latest venture and after running international operations for his online supermarket that specialises in fresh produce - Danny is asking for your support to analyse his sales performance.

In June 2020 - large scale supply changes were made at Data Mart. All Data Mart products now use sustainable packaging methods in every single step from the farm all the way to the customer.

Danny needs your help to quantify the impact of this change on the sales performance for Data Mart and it’s separate business areas.

The key business question he wants you to help him answer are the following:

- What was the quantifiable impact of the changes introduced in June 2020?
- Which platform, region, segment and customer types were the most impacted by this change?
- What can we do about future introduction of similar sustainability updates to the business to minimise impact on sales?


# DATASETS 

One dataset : 
* weekly_sales

## TABLE 1 : weekly_sales

The `weekly_sales` table is composed of : 
- Data Mart has international operations using a multi-`region` strategy
- Data Mart has both, a retail and online `platform` in the form of a Shopify store front to serve their customers
- Customer `segment` and `customer_type` data relates to personal age and demographics information that is shared with Data Mart
- `transactions` is the count of unique purchases made through Data Mart and sales is the actual dollar amount of purchases

![weekly_sales_table](img/weekly_sales_table.png)

# CASE STUDY 

**LOAD INIT SQL FILE BEFORE TO INITIALIZE TABLES**

## Data Cleansing Steps

```sql 
DROP TABLE IF EXISTS data_mart.clean_weekly_sales;
CREATE TABLE data_mart.clean_weekly_sales 
(
  week_date DATE, 
  week_number INTEGER,
  month_number INTEGER,
  calendar_year INTEGER,
  region STRING, 
  plateform STRING, 
  segment STRING, 
  age_band STRING,
  demographic STRING,
  customer_type STRING, 
  transactions INTEGER, 
  sales INTEGER, 
  avg_transaction FLOAT64
)
AS (
  SELECT 
    week_date, 
    EXTRACT(WEEK(MONDAY) FROM week_date) AS week_number,
    EXTRACT(MONTH FROM week_date) AS month_number,
    EXTRACT(YEAR FROM week_date) AS calendar_year,
    region, 
    platform, 
    segment,
    CASE 
      WHEN segment LIKE '%1%' THEN "Young Adults"
      WHEN segment LIKE '%2%' THEN "Middle Aged"
      WHEN segment LIKE '%3%'OR segment LIKE '%4%' THEN "Retirees"
      ELSE "unknown"
    END AS age_band,
    CASE 
      WHEN segment LIKE '%C%' THEN "Couples"
      WHEN segment LIKE '%F%' THEN "Families"
      ELSE "unknown"
    END AS demographic,
    customer_type, 
    transactions, 
    sales, 
    ROUND(sales/transactions, 2)
  FROM `ferrous-syntax-352217.data_mart.weekly_sales`
);
```
# Data Exploration

## **Q1**

> What day of the week is used for each `week_date` value?

```sql
SELECT 
  FORMAT_DATE('%A', week_date) AS week_day,
  COUNT(*)
FROM data_mart.clean_weekly_sales
GROUP BY 1; 
```
**Monday**

## **Q2**

> What range of week numbers are missing from the dataset?

```sql
SELECT 
  week_number 
FROM data_mart.clean_weekly_sales
GROUP BY 1
ORDER BY 1; 
```
[1-11] & [37-52]

We can have a list of these values 

```sql
WITH all_week_numbers AS (
 SELECT 
  *
 FROM UNNEST(GENERATE_ARRAY(1, 52)) AS week_number 
)
SELECT
  week_number 
FROM all_week_numbers AS t1
WHERE NOT EXISTS (
  SELECT 1
  FROM data_mart.clean_weekly_sales AS t2
  WHERE t1.week_number = t2.week_number
)
```
## **Q3**

 > How many total transactions were there for each year in the dataset?

 ```sql
SELECT 
  calendar_year, 
  SUM(transactions) AS total_transactions 
FROM data_mart.clean_weekly_sales 
GROUP BY calendar_year
ORDER BY 2 DESC; 
 ```
![transactions_by_year](img/transactions_by_year.png)

## **Q4**

> What is the total sales for each region for each month?

```sql
SELECT 
  region, 
  month_number, 
  SUM(sales) AS total_sales
FROM `data_mart.clean_weekly_sales`
GROUP BY 
  region, 
  month_number
ORDER BY
  region, 
  month_number;
```
![total_sales_by_region_month](img/total_sales_by_region_month.png)

## **Q5**

> What is the total count of transactions for each platform

```sql
SELECT 
  plateform, 
  SUM(transactions) AS transactions_number
FROM data_mart.clean_weekly_sales 
GROUP BY 
  plateform; 
```
![transactions_number_by_plateforme](img/transactions_number_by_plateforme.png)

## **Q6**

> What is the percentage of sales for Retail vs Shopify for each month?

```sql
WITH cte_total_sales AS (
  SELECT
    calendar_year,
    month_number, 
    plateform, 
    SUM(sales) AS monthly_sales 
FROM data_mart.clean_weekly_sales 
GROUP BY 
  calendar_year, 
  month_number, 
  plateform 
)
SELECT 
  calendar_year, 
  month_number, 
  ROUND(
    100 * MAX(CASE WHEN plateform = "Retail" THEN monthly_sales ELSE NULL END) / 
    SUM(monthly_sales), 
    2
   ) AS retail_sales, 
  ROUND(
    100 * MAX(CASE WHEN plateform = "Shopify" THEN monthly_sales ELSE NULL END) / 
    SUM(monthly_sales),
    2
  ) AS shopify_sales
FROM cte_total_sales 
GROUP BY 
  calendar_year, 
  month_number
ORDER BY 
  calendar_year, 
  month_number;
```
![plateform_sales_by_month_year](img/plateform_sales_by_month_year.png)

## **Q7**

> What is the percentage of sales by demographic for each year in the dataset?

```sql
WITH cte_total_sales AS (
  SELECT
    calendar_year,
    demographic, 
    SUM(sales) AS yearly_sales
FROM data_mart.clean_weekly_sales 
GROUP BY 
  calendar_year, 
  demographic
)
SELECT 
  calendar_year, 
  ROUND(
    100 * MAX(CASE WHEN demographic = "Couples" THEN yearly_sales ELSE NULL END) / 
    SUM(yearly_sales), 
    2
   ) AS couples_sales, 
  ROUND(
    100 * MAX(CASE WHEN demographic = "Families" THEN yearly_sales ELSE NULL END) / 
    SUM(yearly_sales),
    2
  ) AS families_sales, 
  ROUND(
    100 * MAX(CASE WHEN demographic = "unknown" THEN yearly_sales ELSE NULL END) / 
    SUM(yearly_sales),
    2
  ) AS unknown_sales
FROM cte_total_sales 
GROUP BY 
  calendar_year
ORDER BY 
  calendar_year; 
```
![sales_demographic_by_year](img/demographic_by_year.png)

## **Q8**

> Which age_band and demographic values contribute the most to Retail sales?

```sql
WITH cte_total_sales AS (
  SELECT
    plateform,
    demographic, 
    SUM(sales) AS total_sales
FROM data_mart.clean_weekly_sales 
GROUP BY 
  plateform,
  demographic
)
SELECT 
  plateform,
  ROUND(
    100 * MAX(CASE WHEN demographic = "Couples" THEN total_sales ELSE NULL END) / 
    SUM(total_sales), 
    2
   ) AS couples_sales, 
  ROUND(
    100 * MAX(CASE WHEN demographic = "Families" THEN total_sales ELSE NULL END) / 
    SUM(total_sales),
    2
  ) AS families_sales, 
  ROUND(
    100 * MAX(CASE WHEN demographic = "unknown" THEN total_sales ELSE NULL END) / 
    SUM(total_sales),
    2
  ) AS unknown_sales
FROM cte_total_sales 
WHERE plateform = "Retail"
GROUP BY 
  plateform;
```
**Families : 32.18%**

```sql
WITH cte_total_sales AS (
  SELECT
    plateform,
    age_band, 
    SUM(sales) AS total_sales
FROM data_mart.clean_weekly_sales 
GROUP BY 
  plateform,
  age_band
)
SELECT 
  plateform,
  ROUND(
    100 * MAX(CASE WHEN age_band = "Young Adults" THEN total_sales ELSE NULL END) / 
    SUM(total_sales), 
    2
   ) AS young_adults_sales, 
  ROUND(
    100 * MAX(CASE WHEN age_band = "Middle Aged" THEN total_sales ELSE NULL END) / 
    SUM(total_sales),
    2
  ) AS middle_aged_sales, 
  ROUND(
    100 * MAX(CASE WHEN age_band = "Retirees" THEN total_sales ELSE NULL END) / 
    SUM(total_sales),
    2
  ) AS retirees_sales,
  ROUND(
    100 * MAX(CASE WHEN age_band = "unknown" THEN total_sales ELSE NULL END) / 
    SUM(total_sales),
    2
  ) AS unknown_sales
FROM cte_total_sales 
WHERE plateform = "Retail"
GROUP BY 
  plateform;
```

**Retirees : 32.8%**

**Families and Retiress are the categories which contribute the most to the Retail sales**

## **Q9**

> Can we use the `avg_transaction` column to find the average transaction size for each year for Retail vs Shopify? If not - how would you calculate it instead?

```sql
WITH cte_avg_transac_by_year_plateform AS (
  SELECT 
    calendar_year,
    plateform, 
    SUM(transactions) AS total_transactions, 
    SUM(sales) AS total_sales 
  FROM data_mart.clean_weekly_sales
  GROUP BY 
    calendar_year, 
    plateform
) 
SELECT 
  calendar_year, 
  plateform, 
  ROUND(total_sales/total_transactions) AS avg_transaction 
FROM cte_avg_transac_by_year_plateform
ORDER BY calendar_year;
```

![avg_transaction](img/avg_transaction.png)

# Before & After Analysis 

*This technique is usually used when we inspect an important event and want to inspect the impact before and after a certain point in time.*

**Event date : `2020-06-15`**

Before further analysis, we have to create two new tables : one before the event and one after the event. 

```sql
DROP TABLE IF EXISTS `ferrous-syntax-352217`.data_mart.weekly_sales_before_event; 
CREATE TABLE `ferrous-syntax-352217`.data_mart.weekly_sales_before_event AS (
  SELECT 
    week_date, 
    SUM(sales) AS total_sales,
    SUM(transactions) AS total_transactions,
    SUM(sales)/SUM(transactions) AS avg_transaction, 
    ROW_NUMBER() OVER( 
      ORDER BY week_date DESC
    ) AS _row_number
  FROM data_mart.clean_weekly_sales 
  WHERE week_date < "2020-06-15"
  GROUP BY week_date
);

DROP TABLE IF EXISTS `ferrous-syntax-352217`.data_mart.weekly_sales_after_event; 
CREATE TABLE `ferrous-syntax-352217`.data_mart.weekly_sales_after_event AS (
  SELECT 
    week_date, 
    SUM(sales) AS total_sales,
    SUM(transactions) AS total_transactions,
    SUM(sales)/SUM(transactions) AS avg_transaction, 
    ROW_NUMBER() OVER( 
      ORDER BY week_date 
    ) AS _row_number
  FROM data_mart.clean_weekly_sales 
  WHERE week_date >= "2020-06-15"
  GROUP BY week_date
)
```

After that we can select both 4 weeks after and before. 
Then, we aggregate them. 

```sql
WITH cte_total_sales_4_weeks AS (
  SELECT 
    "before" AS event_state,
    SUM(total_sales) AS total_sales_4_weeks, 
    SUM(total_sales)/SUM(total_transactions) AS avg_transaction
  FROM data_mart.weekly_sales_before_event
  WHERE _row_number <= 4
  UNION ALL 
  SELECT 
    "after" AS event_state, 
    SUM(total_sales) AS total_sales_4_weeks,  
    SUM(total_sales)/SUM(total_transactions) AS avg_transaction
  FROM data_mart.weekly_sales_after_event
  WHERE _row_number <= 4
), 
cte_ranked_period AS (
  SELECT 
    event_state, 
    total_sales_4_weeks, 
    avg_transaction, 
    ROW_NUMBER() OVER(
      ORDER BY event_state DESC
    ) AS _row_state_order
  FROM cte_total_sales_4_weeks
), 
cte_diff_bw_after_before AS (
  SELECT 
    event_state, 
    total_sales_4_weeks, 
    avg_transaction, 
    LAG(total_sales_4_weeks) OVER(
      ORDER BY _row_state_order
    ) AS previous_total_sales, 
    LAG(avg_transaction) OVER(
      ORDER BY _row_state_order
    ) AS previous_avg_transaction
  FROM cte_ranked_period 
)
SELECT 
  total_sales_4_weeks - previous_total_sales AS sales_diff, 
  ROUND(
      100 * ((CAST(total_sales_4_weeks AS NUMERIC) / previous_total_sales) - 1),
      2
    ) AS sales_change
FROM cte_diff_bw_after_before
WHERE event_state = "after";
```
![4_weeks_after_before](img/4_weeks_after_before.png)

We can filter 12 weeks before. 

```sql
WITH cte_total_sales_4_weeks AS (
  SELECT 
    "before" AS event_state,
    SUM(total_sales) AS total_sales_4_weeks, 
    SUM(total_sales)/SUM(total_transactions) AS avg_transaction
  FROM data_mart.weekly_sales_before_event
  WHERE _row_number <= 12
  UNION ALL 
  SELECT 
    "after" AS event_state, 
    SUM(total_sales) AS total_sales_4_weeks,  
    SUM(total_sales)/SUM(total_transactions) AS avg_transaction
  FROM data_mart.weekly_sales_after_event
  WHERE _row_number <= 12
)
```
![12_weeks_after_before](img/12_weeks_after_before.png)


> How do the sale metrics for these 2 periods before and after compare with the previous years in 2018 and 2019?

We have to seperate years 2019/2020 and year 2018 because of one week delay. 

```sql
DROP TABLE IF EXISTS `ferrous-syntax-352217`.data_mart.weekly_sales_before_event; 
CREATE TABLE `ferrous-syntax-352217`.data_mart.weekly_sales_before_event AS (
  SELECT 
    calendar_year,
    week_number, 
    SUM(sales) AS total_sales,
    SUM(transactions) AS total_transactions,
    SUM(sales)/SUM(transactions) AS avg_transaction, 
    ROW_NUMBER() OVER( 
      PARTITION BY calendar_year
      ORDER BY week_number DESC
    ) AS _row_number
  FROM data_mart.clean_weekly_sales 
  WHERE week_number < 24
  GROUP BY 
    calendar_year, 
    week_number
);

DROP TABLE IF EXISTS `ferrous-syntax-352217`.data_mart.weekly_sales_after_event; 
CREATE TABLE `ferrous-syntax-352217`.data_mart.weekly_sales_after_event AS (
  SELECT 
    calendar_year, 
    week_number,
    SUM(sales) AS total_sales,
    SUM(transactions) AS total_transactions,
    SUM(sales)/SUM(transactions) AS avg_transaction, 
    ROW_NUMBER() OVER( 
      PARTITION BY calendar_year
      ORDER BY week_number 
    ) AS _row_number
  FROM data_mart.clean_weekly_sales 
  WHERE week_number >= 24
  GROUP BY 
    calendar_year,
    week_number
);

DROP TABLE IF EXISTS `ferrous-syntax-352217`.data_mart.weekly_sales_before_event_2018; 
CREATE TABLE `ferrous-syntax-352217`.data_mart.weekly_sales_before_event_2018 AS (
  SELECT 
    calendar_year,
    week_number, 
    SUM(sales) AS total_sales,
    SUM(transactions) AS total_transactions,
    SUM(sales)/SUM(transactions) AS avg_transaction, 
    ROW_NUMBER() OVER( 
      PARTITION BY calendar_year
      ORDER BY week_number DESC
    ) AS _row_number
  FROM data_mart.clean_weekly_sales 
  WHERE week_number < 25
  GROUP BY 
    calendar_year, 
    week_number
);

DROP TABLE IF EXISTS `ferrous-syntax-352217`.data_mart.weekly_sales_after_event_2018; 
CREATE TABLE `ferrous-syntax-352217`.data_mart.weekly_sales_after_event_2018 AS (
  SELECT 
    calendar_year, 
    week_number,
    SUM(sales) AS total_sales,
    SUM(transactions) AS total_transactions,
    SUM(sales)/SUM(transactions) AS avg_transaction, 
    ROW_NUMBER() OVER( 
      PARTITION BY calendar_year
      ORDER BY week_number 
    ) AS _row_number
  FROM data_mart.clean_weekly_sales 
  WHERE week_number >= 25
  GROUP BY 
    calendar_year,
    week_number
);
```
After creating the tables, we can use them to calculate the difference between 4 weeks before/after the event by year. 

```sql
CREATE TEMP TABLE weekly_sales_4weeks_2019_2020 AS (
WITH cte_total_sales_4_weeks AS (
  SELECT 
    calendar_year,
    "1.before" AS event_state,
    SUM(total_sales) AS total_sales_4_weeks, 
    SUM(total_sales)/SUM(total_transactions) AS avg_transaction
  FROM data_mart.weekly_sales_before_event
  WHERE _row_number <= 4
  GROUP BY calendar_year
  UNION ALL 
  SELECT 
    calendar_year,
    "2.after" AS event_state, 
    SUM(total_sales) AS total_sales_4_weeks,  
    SUM(total_sales)/SUM(total_transactions) AS avg_transaction
  FROM data_mart.weekly_sales_after_event
  WHERE _row_number <= 4
  GROUP BY calendar_year
),
cte_diff_bw_after_before AS (
  SELECT 
    calendar_year,
    event_state, 
    total_sales_4_weeks, 
    avg_transaction, 
    LAG(total_sales_4_weeks) OVER(
      PARTITION BY calendar_year
      ORDER BY event_state 
    ) AS previous_total_sales, 
    LAG(avg_transaction) OVER(
      PARTITION BY calendar_year
      ORDER BY event_state 
    ) AS previous_avg_transaction
  FROM cte_total_sales_4_weeks
)
SELECT 
  calendar_year,
  total_sales_4_weeks - previous_total_sales AS sales_diff, 
  ROUND(
      100 * ((CAST(total_sales_4_weeks AS NUMERIC) / previous_total_sales) - 1),
      2
    ) AS sales_change
FROM cte_diff_bw_after_before 
WHERE event_state = "2.after"
AND calendar_year IN (2019, 2020)
ORDER BY calendar_year
); 

CREATE TEMP TABLE weekly_sales_4weeks_2018 AS (
WITH cte_total_sales_4_weeks AS (
  SELECT 
    calendar_year,
    "1.before" AS event_state,
    SUM(total_sales) AS total_sales_4_weeks, 
    SUM(total_sales)/SUM(total_transactions) AS avg_transaction
  FROM data_mart.weekly_sales_before_event_2018
  WHERE _row_number <= 4
  GROUP BY calendar_year
  UNION ALL 
  SELECT 
    calendar_year,
    "2.after" AS event_state, 
    SUM(total_sales) AS total_sales_4_weeks,  
    SUM(total_sales)/SUM(total_transactions) AS avg_transaction
  FROM data_mart.weekly_sales_after_event_2018
  WHERE _row_number <= 4
  GROUP BY calendar_year
),
cte_diff_bw_after_before AS (
  SELECT 
    calendar_year,
    event_state, 
    total_sales_4_weeks, 
    avg_transaction, 
    LAG(total_sales_4_weeks) OVER(
      PARTITION BY calendar_year
      ORDER BY event_state 
    ) AS previous_total_sales, 
    LAG(avg_transaction) OVER(
      PARTITION BY calendar_year
      ORDER BY event_state 
    ) AS previous_avg_transaction
  FROM cte_total_sales_4_weeks
)
SELECT 
  calendar_year,
  total_sales_4_weeks - previous_total_sales AS sales_diff, 
  ROUND(
      100 * ((CAST(total_sales_4_weeks AS NUMERIC) / previous_total_sales) - 1),
      2
    ) AS sales_change
FROM cte_diff_bw_after_before 
WHERE event_state = "2.after"
AND calendar_year = 2018
); 

SELECT * FROM weekly_sales_4weeks_2018
UNION ALL
SELECT * FROM weekly_sales_4weeks_2019_2020
ORDER BY calendar_year; 
```
![4_weeks_after_before_by_year](img/4_weeks_after_before_by_year.png)

If we want to do the same with 12 weeks, the only thing is to modify this part : 

```sql
  SELECT 
    calendar_year,
    "1.before" AS event_state,
    SUM(total_sales) AS total_sales_4_weeks, 
    SUM(total_sales)/SUM(total_transactions) AS avg_transaction
  FROM data_mart.weekly_sales_before_event_2018
  WHERE _row_number <= 4
  GROUP BY calendar_year
  UNION ALL 
  SELECT 
    calendar_year,
    "2.after" AS event_state, 
    SUM(total_sales) AS total_sales_4_weeks,  
    SUM(total_sales)/SUM(total_transactions) AS avg_transaction
  FROM data_mart.weekly_sales_after_event_2018
  WHERE _row_number <= 4
  GROUP BY calendar_year
```
![12_weeks_after_before_by_year](img/12_weeks_after_before_by_year.png)

# Bonus Question

Which areas of the business have the highest negative impact in sales metrics performance in 2020 for the 12 week before and after period?

* region
* platform
* age_band
* demographic
* customer_type

## region 

```sql
CREATE TEMP TABLE weekly_sales_12weeks_2020 AS (
WITH cte_total_sales_12_weeks AS (
  SELECT 
    region,
    "1.before" AS event_state,
    SUM(total_sales) AS total_sales_12_weeks, 
  FROM data_mart.weekly_sales_before_event
  WHERE _row_number <= 12
  GROUP BY region
  UNION ALL 
  SELECT 
    region,
    "2.after" AS event_state, 
    SUM(total_sales) AS total_sales_12_weeks,  
  FROM data_mart.weekly_sales_after_event
  WHERE _row_number <= 12
  GROUP BY region
),
cte_diff_bw_after_before AS (
  SELECT 
    region,
    event_state, 
    total_sales_12_weeks,
    LAG(total_sales_12_weeks) OVER(
      PARTITION BY region
      ORDER BY event_state 
    ) AS previous_total_sales, 
  FROM cte_total_sales_12_weeks
)
SELECT 
  region,
  total_sales_12_weeks - previous_total_sales AS sales_diff, 
  ROUND(
      100 * ((CAST(total_sales_12_weeks AS NUMERIC) / previous_total_sales) - 1),
      2
    ) AS sales_change
FROM cte_diff_bw_after_before 
WHERE event_state = "2.after"
); 


SELECT * 
FROM weekly_sales_12weeks_2020
ORDER BY sales_change; 
```

![12_weeks_after_before_region](img/12_weeks_after_before_region.png)

## plateform

```sql
CREATE TEMP TABLE weekly_sales_12weeks_2020 AS (
WITH cte_total_sales_12_weeks AS (
  SELECT 
    plateform,
    "1.before" AS event_state,
    SUM(total_sales) AS total_sales_12_weeks, 
  FROM data_mart.weekly_sales_before_event
  WHERE _row_number <= 12
  GROUP BY plateform
  UNION ALL 
  SELECT 
    plateform,
    "2.after" AS event_state, 
    SUM(total_sales) AS total_sales_12_weeks,  
  FROM data_mart.weekly_sales_after_event
  WHERE _row_number <= 12
  GROUP BY plateform
),
cte_diff_bw_after_before AS (
  SELECT 
    plateform,
    event_state, 
    total_sales_12_weeks,
    LAG(total_sales_12_weeks) OVER(
      PARTITION BY plateform
      ORDER BY event_state 
    ) AS previous_total_sales, 
  FROM cte_total_sales_12_weeks
)
SELECT 
  plateform,
  total_sales_12_weeks - previous_total_sales AS sales_diff, 
  ROUND(
      100 * ((CAST(total_sales_12_weeks AS NUMERIC) / previous_total_sales) - 1),
      2
    ) AS sales_change
FROM cte_diff_bw_after_before 
WHERE event_state = "2.after"
); 
```
![12_weeks_after_before_plateform](img/12_weeks_after_before_plateform.png)

## age band

![12_weeks_after_before_ageband](img/12_weeks_after_before_ageband.png)

## demographic

![12_weeks_after_before_demographic](img/12_weeks_after_before_demographic.png)

## customer type

![12_weeks_after_before_customertype](img/12_weeks_after_before_customertype.png)

The date coincides with the end of plastic bags in Australia. This shows that new customers have new consumer habits. 
This is also why retail is less popular and online sales are more important.