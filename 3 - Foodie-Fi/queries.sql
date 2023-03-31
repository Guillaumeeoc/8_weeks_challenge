
/*

YOU HAVE TO CREATE THE DATABASE BEFORE
ALL THE SQL QUERY IS IN init.sql 

*/ 

--create views to not overlap data sources

DROP SCHEMA IF EXISTS v_foodie_fi CASCADE; 
CREATE SCHEMA v_foodie_fi; 

DROP VIEW IF EXISTS v_foodie_fi.plans; 
CREATE VIEW v_foodie_fi.plans AS
SELECT * FROM foodie_fi.plans; 

DROP VIEW IF EXISTS v_foodie_fi.subscriptions; 
CREATE VIEW v_foodie_fi.subscriptions AS
SELECT * FROM foodie_fi.subscriptions; 

/* CUSTOMER JOURNEY */

SELECT 
  customer_id, 
  plans.plan_id, 
  start_date, 
  plans.plan_name, 
  RANK() OVER(
    PARTITION BY customer_id
    ORDER BY start_date
  )
FROM v_foodie_fi.subscriptions
INNER JOIN v_foodie_fi.plans 
  ON subscriptions.plan_id = plans.plan_id
WHERE customer_id in (1, 2, 11, 13, 15, 16, 18, 19);

/* EDA */

--how many customers has Foodie-Fi ever had?

SELECT 
  COUNT(DISTINCT customer_id) AS customers_number
FROM v_foodie_fi.subscriptions;


--what is the monthly distribution of trial plan start_date values for our dataset - use the start of the month as the group by value

WITH cte_month_distribution AS (
  SELECT 
    *, 
    TO_CHAR(start_date, 'Month') AS month
  FROM v_foodie_fi.subscriptions
  WHERE plan_id = 0
)
SELECT 
  month, 
  COUNT(*) AS trials_number
FROM cte_month_distribution
GROUP BY 1
ORDER BY 2 DESC; 


--what plan start_date values occur after the year 2020 for our dataset? Show the breakdown by count of events for each plan_name

SELECT 
  plans.plan_id, 
  plans.plan_name, 
  COUNT(*) AS events 
FROM v_foodie_fi.subscriptions
LEFT JOIN v_foodie_fi.plans
  ON subscriptions.plan_id =  plans.plan_id
WHERE start_date > '2020-12-31'
GROUP BY 1, 2
ORDER BY 1; 

--what is the customer count and percentage of customers who have churned rounded to 1 decimal place?


WITH cte_flag_churn AS (
  SELECT 
    *, 
    CASE 
      WHEN plan_id = 4 THEN 1 
      ELSE 0
    END AS flag_churn 
  FROM v_foodie_fi.subscriptions
)
SELECT 
  flag_churn,
  COUNT(*) AS churn_count,
  ROUND( 
    100 * COUNT(*) / SUM(COUNT(*)) OVER(), 
    1
  ) AS churn_percentage
FROM cte_flag_churn
GROUP BY 1;

--how many customers have churned straight after their initial free trial - what percentage is this rounded to the nearest whole number?

WITH cte_previous_plan AS (
  SELECT 
    *, 
    LAG(plan_id) OVER(
      PARTITION BY customer_id
      ORDER BY start_date) AS previous_plan 
  FROM v_foodie_fi.subscriptions
),
cte_flag_churn_after_trial AS (
  SELECT
    *, 
    CASE 
      WHEN plan_id = 4 AND previous_plan = 0 THEN 1
      ELSE 0
    END AS flag_churn_after_trial
  FROM cte_previous_plan
) 
SELECT 
  flag_churn_after_trial, 
  COUNT(*) AS churn_after_trial_number, 
  ROUND(COUNT(*) / SUM(COUNT(*)) OVER(), 2) AS churn_after_trail_percentage
FROM cte_flag_churn_after_trial
GROUP BY 1; 

--what is the number and percentage of customer plans after their initial free trial?

WITH cte_previous_plan AS (
  SELECT 
    *, 
    LAG(plan_id) OVER(
      PARTITION BY customer_id
      ORDER BY start_date) AS previous_plan 
  FROM v_foodie_fi.subscriptions
)
SELECT 
  plan_id, 
  COUNT(*) AS customer_count,
  ROUND(COUNT(*) / SUM(COUNT(*)) OVER(), 2) AS percentage
FROM cte_previous_plan 
WHERE previous_plan = 0
GROUP BY plan_id;

--what is the customer count and percentage breakdown of all 5 plan_name values at 2020-12-31?

WITH cte_breakdown_2020 AS (
  SELECT 
    customer_id, 
    plan_id, 
    start_date, 
    ROW_NUMBER() OVER(
      PARTITION BY customer_id
      ORDER BY start_date DESC
    ) AS _row_number
  FROM v_foodie_fi.subscriptions
  WHERE start_date <= '2020-12-31'
)
SELECT 
  cte_breakdown_2020.plan_id, 
  plans.plan_name, 
  COUNT(*) AS customer_count, 
  ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER(), 1) AS percentage
FROM cte_breakdown_2020
LEFT JOIN v_foodie_fi.plans
  ON cte_breakdown_2020.plan_id = plans.plan_id
WHERE _row_number = 1
GROUP BY 1, 2;

--how many customers have upgraded to an annual plan in 2020?

SELECT 
  COUNT(DISTINCT customer_id) AS customer_count
FROM v_foodie_fi.subscriptions
WHERE plan_id = 3
AND start_date BETWEEN '2020-01-01' AND '2020-12-31';

--how many days on average does it take for a customer to an annual plan from the day they join Foodie-Fi?

DROP TABLE IF EXISTS join_date; 
CREATE TEMP TABLE join_date AS (
  WITH cte_join_date AS (
    SELECT 
      *, 
      ROW_NUMBER() OVER(
        PARTITION BY customer_id
        ORDER BY start_date
      ) AS _row_number
    FROM foodie_fi.subscriptions
  )
  SELECT 
    customer_id, 
    start_date AS signup_date
  FROM cte_join_date 
  WHERE _row_number = 1
);


DROP TABLE IF EXISTS date_to_annual_plan; 
CREATE TEMP TABLE date_to_annual_plan AS (
  WITH cte_date_to_annual_plan AS (
    SELECT 
      *, 
      ROW_NUMBER() OVER(
        PARTITION BY customer_id
        ORDER BY start_date DESC 
      ) AS _row_number
    FROM foodie_fi.subscriptions
  )
  SELECT 
    customer_id, 
    start_date AS annual_plan_date
  FROM cte_date_to_annual_plan
  WHERE _row_number = 1
  AND plan_id = 3
); 


WITH cte_days_diff_until_annual_plan AS (
  SELECT 
   date_to_annual_plan.customer_id, 
   join_date.signup_date, 
   annual_plan_date
  FROM date_to_annual_plan
  LEFT JOIN join_date
    ON date_to_annual_plan.customer_id = join_date.customer_id
), 
cte_avg_diff_days AS (
  SELECT 
    customer_id, 
    DATE_PART('day', annual_plan_date::timestamp - signup_date::timestamp) AS days_diff
  FROM cte_days_diff_until_annual_plan
)
SELECT 
  FLOOR(AVG(days_diff)) AS avg_diff_days
FROM cte_avg_diff_days;

--how many customers downgraded from a pro monthly to a basic monthly plan in 2020?

WITH cte_previous_plan AS (
  SELECT 
    customer_id, 
    plan_id, 
    LAG(plan_id) OVER(
      PARTITION BY customer_id
      ORDER BY start_date DESC
    ) AS previous_plan, 
    start_date
  FROM foodie_fi.subscriptions
  WHERE start_date <= '2020-12-31'
)
SELECT 
  COUNT(*)
FROM cte_previous_plan
WHERE previous_plan = 2
AND plan_id = 1;