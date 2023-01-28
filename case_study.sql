-- ************************************************************************************************************************

DROP SCHEMA IF EXISTS foodie_fi;
CREATE SCHEMA foodie_fi;

-- ************************************************************************************************************************

USE foodie_fi;

-- ************************************************************************************************************************

-- Create plans table
DROP TABLE IF EXISTS plans;
CREATE TABLE plans (
    plan_id INT NOT NULL,
    plan_name TEXT,
    price DECIMAL(5 , 2 ),
    PRIMARY KEY (plan_id)
);

-- ************************************************************************************************************************

-- Insert data into plans table 
INSERT INTO plans VALUES
(0, "trial", 0), (1, "basic monthly", "9.90"), (2, "pro monthly", "19.90"), (3, "pro annual", "199"),
(4, "churn", null);

-- ************************************************************************************************************************

-- Create subscriptions table
DROP TABLE IF EXISTS subscriptions;
CREATE TABLE subscriptions (
    customer_id INT,
    plan_id INT,
    start_date DATE,
    FOREIGN KEY (plan_id)
        REFERENCES plans (plan_id)
);

-- ************************************************************************************************************************

-- Insert data into subscriptions table
INSERT INTO subscriptions VALUES
('1', '0', '2020-08-01'),
  ('1', '1', '2020-08-08'),
  ('2', '0', '2020-09-20'),
  ('2', '3', '2020-09-27'),
  ('11', '0', '2020-11-19'),
  ('11', '4', '2020-11-26'),
  ('13', '0', '2020-12-15'),
  ('13', '1', '2020-12-22'),
  ('13', '2', '2021-03-29'),
  ('15', '0', '2020-03-17'),
  ('15', '2', '2020-03-24'),
  ('15', '4', '2020-04-29'),
  ('16', '0', '2020-05-31'),
  ('16', '1', '2020-06-07'),
  ('16', '3', '2020-10-21'),
  ('18', '0', '2020-07-06'),
  ('18', '2', '2020-07-13'),
  ('19', '0', '2020-06-22'),
  ('19', '2', '2020-06-29'),
  ('19', '3', '2020-08-29');
  
-- ************************************************************************************************************************
-- A. Customers Journey
-- ************************************************************************************************************************
SELECT 
    s.customer_id, s.plan_id ,p.plan_name, s.start_date
FROM
    subscriptions s
        JOIN
    plans p ON p.plan_id = s.plan_id
ORDER BY s.customer_id , s.start_date;

-- ************************************************************************************************************************
-- B. Data Analysis
-- ************************************************************************************************************************
-- 1. How many customers has Foodie-Fi ever had?
SELECT 
    COUNT(DISTINCT customer_id)
FROM
    subscriptions;

-- ************************************************************************************************************************

-- 2. What is the monthly distribution of trial plan start_date values for our dataset — use the start of the month as the GROUP BY value
SELECT 
    DATE_FORMAT(start_date,'%M') AS Months,
    COUNT(customer_id) 'No of Customers'
FROM
    subscriptions
GROUP BY Months
ORDER BY COUNT(customer_id) desc;

-- ************************************************************************************************************************

-- 3. What plan ‘start_date’ values occur after the year 2020 for our dataset? Show the breakdown by count of events for each 'plan_name'
SELECT 
    p.plan_name, p.plan_id, COUNT(*) AS 'Cnt of events'
FROM
    subscriptions s
        JOIN
    plans p ON p.plan_id = s.plan_id
WHERE
    start_date >= '2021-01-01'
GROUP BY p.plan_id , p.plan_name
ORDER BY plan_id;

-- *******************************************************************************************************************

-- 4. What is the customer count and percentage of customers who have churned the rounded to 1 decimal place?
SELECT 
	count(customer_id) as 'No of Customers Churned', 
    concat(round(count(customer_id)*100/(select count(distinct(customer_id)) from subscriptions),1),'%') as 'Percent of Customers Churned' 
FROM 
    subscriptions 
WHERE
	plan_id = 4;

-- ************************************************************************************************************************

-- 5. How many customers have churned straight after their initial free trial - what percentage is this rounded to the nearest whole number?
WITH cte_churn AS (
	SELECT 
		*, LAG(plan_id,1) OVER (PARTITION BY customer_id ORDER BY plan_id) AS prev_plan 
	FROM 
		subscriptions)
SELECT 
	count(*) AS cnt_churn, concat(round (count(*) * 100 / (SELECT COUNT(DISTINCT(customer_id)) FROM subscriptions),0),'%') AS perc_churn
FROM 
	cte_churn
WHERE 
plan_id = 4 AND prev_plan = 0;

-- ************************************************************************************************************************

-- 6. What is the number and percentage of customer plans after their initial free trial?
WITH cte AS (
				SELECT 
					*, LEAD(plan_id,1) OVER (PARTITION BY customer_id ORDER BY plan_id) AS next_plan 
				FROM 
					subscriptions
			)
SELECT 
next_plan AS plan_id, Count(*) AS 'Number of customers',
concat(round(count(*) * 100/(SELECT 
						COUNT(DISTINCT customer_id) 
                        FROM 
                        subscriptions),1),'%') AS 'Percentage of customers' 
FROM 
	cte 
WHERE 
	plan_id = 0 AND next_plan IS NOT NULL 
GROUP BY next_plan 
ORDER BY next_plan;

-- ************************************************************************************************************************

-- 7. What is the customer count and percentage breakdown of all 5 plan_name values at 2020–12–31?
WITH cte_next_date AS(
						SELECT 
							*, LEAD(start_date,1) OVER (PARTITION BY customer_id ORDER BY start_date) AS next_date 
						FROM 
							subscriptions 
						WHERE 
							start_date <= '2020-12-31'
					 ), 
plans_breakdown AS(
					SELECT 
						plan_id, count(DISTINCT customer_id) AS num_customer 
					FROM 
						cte_next_date 
					WHERE 
						next_date IS NOT NULL AND start_date <'2020-12-31' AND next_date > '2020-12-31' 
                        OR 
                        next_date IS NULL AND start_date < '2020-12-31'
					GROUP BY plan_id
				  )
SELECT 
	plan_id as 'Plan ID',num_customer AS 'Number of customers', concat(round(num_customer*100/(
													SELECT 
														COUNT(DISTINCT customer_id) 
													FROM 
														subscriptions),1),'%') AS 'Percentage of customers' 
FROM 
	plans_breakdown 
    GROUP BY plan_id, num_customer 
    ORDER BY plan_id;

-- ************************************************************************************************************************

-- 8. How many customers have upgraded to an annual in 2020? 
SELECT 
	count(customer_id) AS 'Number of customers' 
FROM 
	subscriptions 
WHERE 
	start_date <= '2020-12-31' AND plan_id = 3; 

-- ************************************************************************************************************************

-- 9 How many days on average does it take for a customer to an annual plan from the day they joined Foodie-Fi?
WITH annual_plan AS (
						SELECT 
							customer_id, start_date AS annual_date 
                        FROM 
							subscriptions WHERE plan_id = 3
					),
trail_plan as (
						SELECT
							customer_id, start_date AS trail_date 
                        FROM 
							subscriptions 
                            WHERE 
                            plan_id = 0
			  )
SELECT
 round(avg(datediff(annual_date, trail_date)),0) AS 'Average days' 
FROM 
	annual_plan ap 
JOIN 
	trail_plan tp 
ON 
	ap.customer_id = tp.customer_id;  

-- ************************************************************************************************************************

-- 10. Can you further breakdown this average value into 30 day periods? (i.e. 0–30 days, 31–60 days etc)
WITH annual_plan AS (
						SELECT 
							customer_id, start_date AS annual_date 
						FROM 
							subscriptions 
						WHERE 
							plan_id = 3
					),
trail_plan AS (
				SELECT 
					customer_id, start_date AS trail_date 
				FROM 
					subscriptions 
				WHERE 
					plan_id = 0
			  ),
date_diff AS (
				SELECT 
					datediff(annual_date, trail_date) AS days_diff 
                FROM 
					annual_plan ap 
				JOIN 
					trail_plan tp 
				ON 
					ap.customer_id = tp.customer_id
			 ),
day_count AS (
				SELECT 
					*, floor(days_diff/30) AS bins 
				FROM 
					date_diff
			 )
SELECT 
	concat((bins *30)+1,'-',(bins+1)*30,'days') AS Days, count(days_diff) AS 'Total number of customers' 
FROM 
	day_count 
GROUP BY bins 
ORDER BY bins;

-- ************************************************************************************************************************

-- 11. How many customers downgraded from a pro monthly to a basic monthly plan in 2020?
WITH next_plan AS (
					SELECT 
						*, LEAD(plan_id,1) OVER (PARTITION BY customer_id ORDER BY start_date,plan_id) AS plan 
					FROM 
						subscriptions
				   )
SELECT 
	count(DISTINCT customer_id) AS 'Number of customers downgraded' 
FROM 
	next_plan np 
LEFT JOIN 
	plans p 
ON 
	p.plan_id = np.plan_id
WHERE 
	p.plan_name = 'pro_monthly' AND np.plan = 1 AND start_date <= '2020-12-31';

-- ************************************************************************************************************************
-- C. Challenge Payment Question
-- ************************************************************************************************************************
/*
Create a new payments table for the year 2020 that includes amounts paid by each customer in the subscriptions table with the following requirements:
1. monthly payments always occur on the same day of month as the original start_date of any monthly paid plan
2. upgrades from basic to monthly or pro plans are reduced by the current paid amount in that month and start immediately
3. upgrades from pro monthly to pro annual are paid at the end of the current billing period and also starts at the end of the month period
4. once a customer churns they will no longer make payments
*/


	CREATE TEMPORARY TABLE new_tbl 
		SELECT 
			s.customer_id, 
			s.plan_id,
			p.plan_name,
			s.start_date,
			p.price, 
			LEAD(s.plan_id) OVER (PARTITION BY  s.customer_id ORDER BY s.start_date) AS next_id,
			LEAD(s.start_date) OVER (PARTITION BY s.customer_id ORDER BY s.start_date) AS next_date
		FROM 
			subscriptions s 
		JOIN 
			plans p ON p.plan_id = s.plan_id 
		WHERE 
			s.start_date <'2020-12-31' ORDER BY s.customer_id, s.start_date;
CREATE TABLE payments
	WITH RECURSIVE dates_cte(customer_id,plan_id,plan_name,payment_date,amount,next_id,next_date) AS (
		SELECT 
			customer_id,
			plan_id,
			plan_name,
			start_date AS payment_date,
			price AS amount,
			next_id,
			next_date
		FROM
			new_tbl
		WHERE
			(plan_id IN (1 , 2) AND next_id IS NULL)
				OR (plan_id IN (1 , 2)
				AND next_id IS NOT NULL)
		UNION
		SELECT 
			customer_id,
			plan_id,
			plan_name,
			payment_date + INTERVAL 1 MONTH,
			amount,
			next_id,
			next_date
		FROM
			dates_cte
		WHERE
			(next_id IS NULL
			AND payment_date <= '2020-12-31')
			OR (next_id IS NOT NULL
			AND payment_date < next_date - INTERVAL 1 MONTH)
	),
	temp AS(
	SELECT 
		*
	FROM
		dates_cte
	WHERE
		payment_date <= '2020-12-31'
	ORDER BY customer_id , payment_date
	),
	temp1 AS(
		SELECT 
			s.customer_id,
			s.plan_id,
			p.plan_name,
			s.start_date as payment_date,
			p.price as amount
		FROM 
			subscriptions s 
		JOIN 
			plans p ON p.plan_id = s.plan_id 
		WHERE 
			s.plan_id IN (3)
	),
	temp2 AS (
		SELECT s.customer_id,
			s.plan_id,
			p.plan_name,
			s.start_date as payment_date,
			p.price as amount
		FROM 
			subscriptions s 
		JOIN 
			plans p 
		ON 
			p.plan_id = s.plan_id 
		WHERE 
			s.plan_id IN (1,2) 
	), 
	temp3 AS (
		SELECT 
			customer_id,plan_id,plan_name,payment_date,amount 
		FROM 
			temp 
		UNION
		SELECT * from temp1
		UNION
		SELECT * from temp2
	),
payments as (
	SELECT 
		customer_id,
		plan_id,
		plan_name,
		payment_date,
		CASE
			WHEN 
				datediff(payment_date,LAG(payment_date) over (PARTITION BY customer_id ORDER BY payment_date)) < 30 
			THEN 
				amount-LAG(amount) over (PARTITION BY customer_id ORDER BY payment_date)
			ELSE 
				amount
		END as amount,
		RANK() OVER (PARTITION BY customer_id ORDER BY payment_date) as payment_order
		
	FROM
		temp3
	WHERE
		payment_date <= '2020-12-31'
	ORDER BY customer_id , payment_date
    )
    SELECT 
		* 
	FROM 
		payments;
    
SELECT 
    *
FROM
    payments;