-- Name :  Sahil Gupta 
-- Project Name : Customer segmentation analysis to improve conversion


--------------------------------------------------------------- Problem Statement -----------------------------------------------------------------------
-- As an analyst, you're tasked with examining the past purchasing patterns of customers and categorizing them into various segments for crafting personalized 
-- and effective solutions to enhance customer engagement and drive personalized marketing campaigns across various banking products. 
-- The goal is to match each segment with the appropriate product offering.


-- 1. Summary of active vs closed accounts.

SELECT
	"ACCOUNT_STATUS",
	COUNT("ACCOUNT_STATUS") AS total_account_status
FROM
	transaction_line tl
GROUP BY
	1
ORDER BY
	1;
	
-- 2. Breakdown of account types (e.g., loans, credit cards) and their current balances.

SELECT
	"ACCOUNT_CATEGORY",
	COUNT(*) as count,
	SUM("ACCOUNT_BALANCE") AS total_current_balance
FROM
	transaction_line tl
GROUP BY
	1
ORDER BY
	1;

-- 3. Analysis of loan amounts vs. account balances.

SELECT
	"ACCOUNT_CATEGORY",
	AVG("SANCTIONED_AMOUNT") AS avg_loan_amount,
	AVG("ACCOUNT_BALANCE") AS avg_account_balance
FROM
	transaction_line tl
GROUP BY
	1;
	
-- 4. overview of the closure percentages for different loan types by ownership type (Individual vs Joint Account) 

SELECT
	"ACCOUNT_CATEGORY",
	"OWNERSHIP_TYPE",
	COUNT(*) AS total_accounts,
	SUM(CASE WHEN "ACCOUNT_STATUS" = 'Closed' THEN 1 ELSE 0 END) AS closed_accounts,
	ROUND(SUM(CASE WHEN "ACCOUNT_STATUS" = 'Closed' THEN 1 ELSE 0 END)::DECIMAL / COUNT(*) * 100, 2) AS closure_percentage
FROM
	transaction_line tl
GROUP BY
	1,
	2
ORDER BY
	2,
	1;

-- 5. Let’s start by segmenting customers based on FICO scores and account categories to see the distribution.

WITH fico_score_ranges AS (
SELECT
	"CUSTOMER_ID",
	"FICO_SCORE",
	"ACCOUNT_CATEGORY", 
	CASE 
		WHEN "FICO_SCORE" BETWEEN 300 AND 549 THEN 'Very Poor'
		WHEN "FICO_SCORE" BETWEEN 550 AND 649 THEN 'Poor'
		WHEN "FICO_SCORE" BETWEEN 650 AND 749 THEN 'Fair'
		WHEN "FICO_SCORE" BETWEEN 750 AND 849 THEN 'Good'
		WHEN "FICO_SCORE" BETWEEN 850 AND 949 THEN 'Excellent'
	END AS credit_segment
FROM
	transaction_line tl 
) ,
total_customers AS (
SELECT
	COUNT(DISTINCT "CUSTOMER_ID") AS total_customer
FROM
	transaction_line tl 
)
SELECT
	CREDIT_SEGMENT,
	"ACCOUNT_CATEGORY",
	COUNT("CUSTOMER_ID") AS customer_segment_count,
	tc.total_customer,
	(COUNT("CUSTOMER_ID") * 100 / tc.total_customer) AS percentage
FROM
	fico_score_ranges fsr
CROSS JOIN total_customers tc
GROUP BY
	1,
	2,
	4
ORDER BY
	2;


-- 6. Product Usage Segmentation: Categorizing customers by the types of accounts they hold (e.g., Auto Loans, Credit Cards, etc.).

WITH product_segmentation AS (
SELECT
	"CUSTOMER_ID",
	STRING_AGG(DISTINCT "ACCOUNT_CATEGORY", ', ') AS product_mix
FROM
	transaction_line tl
GROUP BY
	"CUSTOMER_ID"
)
SELECT
	product_mix,
	COUNT("CUSTOMER_ID") AS total_customers
FROM
	product_segmentation ps
GROUP BY
	1;


-- 7. Account Activity Segmentation: Segmenting customers by the status of their accounts (whether they have more active or closed accounts).

SELECT
	"CUSTOMER_ID",
	SUM(CASE WHEN "ACCOUNT_STATUS" = 'Active' THEN 1 ELSE 0 END) AS active_accounts,
	SUM(CASE WHEN "ACCOUNT_STATUS" = 'Closed' THEN 1 ELSE 0 END) AS closed_accounts,
	CASE
		WHEN SUM(CASE WHEN "ACCOUNT_STATUS" = 'Active' THEN 1 ELSE 0 END) > SUM(CASE WHEN "ACCOUNT_STATUS" = 'Closed' THEN 1 ELSE 0 END) THEN 'More Active'
		WHEN SUM(CASE WHEN "ACCOUNT_STATUS" = 'Active' THEN 1 ELSE 0 END) < SUM(CASE WHEN "ACCOUNT_STATUS" = 'Closed' THEN 1 ELSE 0 END) THEN 'More Closed'
		ELSE 'EQUAL'
	END AS account_activity_segment
FROM
	transaction_line tl
GROUP BY
	1;


-- 8. Account Activity Segmentation Count 

WITH account_segments AS (
SELECT
	"CUSTOMER_ID",
	SUM(CASE WHEN "ACCOUNT_STATUS" = 'Active' THEN 1 ELSE 0 END) AS active_accounts,
	SUM(CASE WHEN "ACCOUNT_STATUS" = 'Closed' THEN 1 ELSE 0 END) AS closed_accounts,
	CASE
		WHEN SUM(CASE WHEN "ACCOUNT_STATUS" = 'Active' THEN 1 ELSE 0 END) > SUM(CASE WHEN "ACCOUNT_STATUS" = 'Closed' THEN 1 ELSE 0 END) THEN 'More Active'
		WHEN SUM(CASE WHEN "ACCOUNT_STATUS" = 'Active' THEN 1 ELSE 0 END) < SUM(CASE WHEN "ACCOUNT_STATUS" = 'Closed' THEN 1 ELSE 0 END) THEN 'More Closed'
		ELSE 'EQUAL'
	END AS account_activity_segment
FROM
	transaction_line tl
GROUP BY
	1
)
SELECT
	account_activity_segment,
	COUNT("CUSTOMER_ID") AS total_customers
FROM
	account_segments ass
GROUP BY
	1
ORDER BY
	1;


-- 9. Create a cohort to reveal insights into customer retention and the life cycle of accounts. 
-- for example: categorize customers into cohorts based on their account opening dates and then analyse how these cohorts have behaved over time
-- analyse retention Rates (how long accounts stay open across different cohorts)

WITH cohorts AS (
	SELECT
		"CUSTOMER_ID",
		DATE_TRUNC('MONTH',
			CASE
				WHEN "OPENING_DATE" = '' THEN NULL
				ELSE "OPENING_DATE"::DATE
			END
		)::DATE AS cohort_month,
		"ACCOUNT_CATEGORY",
		COALESCE(
			CASE
				WHEN "CLOSED_DATE" = '' THEN NULL
				ELSE "CLOSED_DATE"::DATE
			END,
			NOW()
		)::DATE AS end_date
	FROM
		transaction_line tl
	WHERE
		"OPENING_DATE" != ''
),
cohort_sizes AS (
	SELECT
		cohort_month,
		"ACCOUNT_CATEGORY",
		COUNT(DISTINCT "CUSTOMER_ID") AS total_customers
	FROM
		cohorts c
	GROUP BY
		1,
		2
),
retention AS (
	SELECT
		c.cohort_month,
		c."ACCOUNT_CATEGORY",
		cs.total_customers,
		COUNT(DISTINCT 
				CASE 
	            	WHEN DATE_TRUNC('MONTH', c.end_date) >= c.cohort_month + INTERVAL '12 MONTHS' THEN c."CUSTOMER_ID"         	
				END
	        ) AS retained_customers_after_12_months
	FROM
		cohorts c
	JOIN cohort_sizes cs ON
		c.cohort_month = cs.cohort_month
		AND c."ACCOUNT_CATEGORY" = cs."ACCOUNT_CATEGORY"
	GROUP BY
		1,
		2,
		3
)
SELECT
	cohort_month,
	"ACCOUNT_CATEGORY",
	total_customers,
	retained_customers_after_12_months,
	ROUND((retained_customers_after_12_months::DECIMAL / total_customers::DECIMAL) * 100,
	2) AS retention_rate_after_12_months
FROM
	retention r
WHERE
	cohort_month <= NOW() - INTERVAL '12 MONTHS'
ORDER BY
	1,
	2;
   
-- SUMMARY :- 

-- In simple words, this query:
   
-- Groups customers by when they joined and what type of account they have
-- Counts how many customers are in each group
-- Checks how many customers from each group are still active after 12 months
-- Calculates what percentage of customers are still active after 12 months
-- Shows this information for each month and account type, but only for groups that are at least 12 months old

-- This approach gives you a clear picture of customer retention for different types of accounts over time, focusing on long-term retention (12 months).


-- 10. Identify Common Account Combinations: Look at customers who have multiple account types and identify common combinations.

-- This step aggregates data for each customer:
-- 1. Creates an array of unique account types they have
-- 2. Counts the number of different account types
-- 3. Calculates average FICO score, total balance, and maximum tenure
WITH customer_accounts AS (
	SELECT
		"CUSTOMER_ID",
		ARRAY_AGG(DISTINCT "ACCOUNT_CATEGORY" ORDER by "ACCOUNT_CATEGORY") AS account_types,
		COUNT(DISTINCT "ACCOUNT_CATEGORY") AS num_account_types,
		ROUND(AVG("FICO_SCORE"), 2) AS avg_fico_score,
		SUM("ACCOUNT_BALANCE") AS total_balance,
		MAX("TENURE_MONTHS") AS max_tenure
	FROM
		transaction_line tl
	GROUP BY
		1
)
-- This identifies the most common combinations of account types:
-- 1. Groups by the array of account types
-- 2. Counts how many customers have each combination
SELECT
	account_types,
	COUNT(*) AS combination_count
FROM
	customer_accounts ca
GROUP BY
	1
ORDER BY
	2 DESC;


-- 11. Predict Likely Next Products: Based on product holding patterns and customer behaviour within cohorts

-- This step aggregates data for each customer:
-- 1. Creates an array of unique account types they have
-- 2. Counts the number of different account types
-- 3. Calculates average FICO score, total balance, and maximum tenure
WITH customer_accounts AS (
	SELECT
		"CUSTOMER_ID",
		ARRAY_AGG(DISTINCT "ACCOUNT_CATEGORY" ORDER by "ACCOUNT_CATEGORY") AS account_types,
		COUNT(DISTINCT "ACCOUNT_CATEGORY") AS num_account_types,
		ROUND(AVG("FICO_SCORE"), 2) AS avg_fico_score,
		SUM("ACCOUNT_BALANCE") AS total_balance,
		MAX("TENURE_MONTHS") AS max_tenure
	FROM
		transaction_line tl
	GROUP BY
		1
), 
-- This step:
-- 1. Takes the customer account information
-- 2. Adds a new column 'potential_products' which is an array of account types the customer doesn't currently have
customer_potential AS (
	SELECT
		ca."CUSTOMER_ID",
		ca.account_types,
		ca.num_account_types,
		ca.avg_fico_score,
		ca.total_balance,
		ca.max_tenure,
		(
			SELECT
				ARRAY_AGG(DISTINCT tl."ACCOUNT_CATEGORY")
			FROM
				transaction_line tl
			WHERE
				tl."ACCOUNT_CATEGORY" != ALL(ca.account_types)
		) AS potential_products
	FROM
		customer_accounts ca
)
-- This final step:
-- 1. Selects relevant information for each customer
-- 2. Adds a 'recommended_product' based on simple rules:
	-- 2.1. Credit Card for high FICO score customers without one
	-- 2.2. Investment Account for high balance customers without one
	-- 2.3. Loan Product for long-term customers without one
-- 3. Orders results by total balance and FICO score to prioritize high-value customers
SELECT
	cp."CUSTOMER_ID",
	cp.account_types AS current_products,
	cp.num_account_types,
	cp.avg_fico_score,
	cp.total_balance,
	cp.max_tenure,
	cp.potential_products AS recommended_product
FROM
	customer_potential cp
ORDER BY
	5 DESC,
	4 DESC;


-- Summary of this query: 
-- 1. Identify Common Account Combinations: The account_combinations CTE shows the most common product combinations.
-- 2. Predict Likely Next Products: The potential_products column shows products the customer doesn't have, and 
-- the recommended_product column provides a simple recommendation based on their profile.


-------------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------ Questions ---------------------------------------------------------------------

-- Q1. Which of the Statement is not True?

--	87.50 % Customers with Auto Loans often also have Gold Loans -> Wrong Statement
WITH loan_counts AS (
	SELECT
		"CUSTOMER_ID",
		SUM(CASE WHEN "ACCOUNT_CATEGORY" = 'Auto Loan' THEN 1 ELSE 0 END) AS has_auto_loan,
		SUM(CASE WHEN "ACCOUNT_CATEGORY" = 'Gold Loan' THEN 1 ELSE 0 END) AS has_gold_loan,
		SUM(CASE WHEN "ACCOUNT_CATEGORY" IN ('Consumer Loan', 'Credit Card', 'Housing Loan', 'Personal Loan', 'Two Wheeler Loan') THEN 1 ELSE 0 END) AS has_other_loan
	FROM
		transaction_line tl
	GROUP BY
		"CUSTOMER_ID"
)
SELECT
	COUNT(CASE WHEN has_auto_loan > 0 AND has_gold_loan > 0 THEN 1 END)::DECIMAL / NULLIF(COUNT(CASE WHEN has_auto_loan > 0 THEN 1 END), 0) * 100 AS auto_and_gold_percentage
FROM
	loan_counts lc;

--	In the cohort of 2004-05 for the account category % of active account is 15.7% -> Wrong Statement
WITH total_customers AS (
	SELECT
		EXTRACT(YEAR FROM "OPENING_DATE"::DATE) AS date_2004_to_2005,
		COUNT(*) AS total_customer
	FROM
		transaction_line tl
	WHERE
		"OPENING_DATE"::DATE >= '01-01-2004'
		AND "OPENING_DATE"::DATE < '01-01-2005'
	GROUP BY
		1
)
SELECT
	EXTRACT(YEAR FROM "OPENING_DATE"::DATE) AS date_2004_to_2005,
	COUNT(*) AS active_total_customers,
	tc.total_customer,
	ROUND((COUNT(*)::DECIMAL / tc.total_customer * 100), 2) AS active_account_percentage
FROM
	transaction_line tl
CROSS JOIN total_customers tc
WHERE
	"OPENING_DATE"::DATE >= '01-01-2004'
	AND "OPENING_DATE"::DATE < '01-01-2005'
	AND "ACCOUNT_STATUS" = 'Active'
GROUP BY
	1,
	3;


--	Poor and Good credit score customer count is very highest -> Wrong Statement
WITH fico_score_ranges AS (
	SELECT
		"CUSTOMER_ID",
		"FICO_SCORE",
		"ACCOUNT_CATEGORY", 
		CASE 
			WHEN "FICO_SCORE" BETWEEN 300 AND 549 THEN 'Very Poor'
			WHEN "FICO_SCORE" BETWEEN 550 AND 649 THEN 'Poor'
			WHEN "FICO_SCORE" BETWEEN 650 AND 749 THEN 'Fair'
			WHEN "FICO_SCORE" BETWEEN 750 AND 849 THEN 'Good'
			WHEN "FICO_SCORE" BETWEEN 850 AND 949 THEN 'Excellent'
		END AS fico_score_range
	FROM
		transaction_line tl
) ,
total_customers AS (
	SELECT
		COUNT(DISTINCT "CUSTOMER_ID") AS total_customer
	FROM
		transaction_line tl
)
SELECT
	fico_score_range,
	COUNT("CUSTOMER_ID") AS customer_segment_count
FROM
	fico_score_ranges fsr
CROSS JOIN total_customers tc
GROUP BY
	1
ORDER BY
	2;


--	Average tenure of closing of House loan is 162.45 months -> Correct Statement
SELECT
	"ACCOUNT_CATEGORY",
	ROUND(AVG("TENURE_MONTHS"), 2) AS avg_tenure_month
FROM
	transaction_line tl
WHERE
	"ACCOUNT_STATUS" = 'Closed'
GROUP BY
	1;


-- Q2. Which of the count of unique customers for respective cross selling product category is True
--	Housing Loan - 7995
--	Two-Wheeler Loan - 2772
--	Gold Loan - 2700
--	Auto Loan - 2816

-- ANS : Auto Loan

SELECT
	"ACCOUNT_CATEGORY",
	COUNT(DISTINCT "CUSTOMER_ID") AS total_unique_customers
FROM
	transaction_line tl
WHERE
	"ACCOUNT_CATEGORY" IN ('Housing Loan', 'Two-Wheeler Loan', 'Gold Loan', 'Auto Loan')
GROUP BY
	1;

-- Q3. For Which category of cross sell product category, excellent credit score customer is lowest 
--	Credit card
--	Personal Loan
--	Consumer Loan
--	Auto Loan

-- ANS : Consumer Loan 

SELECT
	"ACCOUNT_CATEGORY",
	COUNT(DISTINCT "CUSTOMER_ID") AS excellent_credit_customers
FROM
	transaction_line tl
WHERE
	"FICO_SCORE" BETWEEN 850 AND 949
	AND "ACCOUNT_CATEGORY" IN ('Credit card', 'Personal Loan', 'Consumer Loan', 'Auto Loan')
GROUP BY
	1
ORDER BY
	2
LIMIT 1;

-- Q4. What is the closure % of joint account holder product category credit card
--	90.13
--	65.69
--	69.65
--	93.19

-- ANS : 65.69 

WITH total_customers AS (
	SELECT
		"ACCOUNT_CATEGORY",
		COUNT(*) AS total_customer
	FROM
		transaction_line tl
	WHERE
		"OWNERSHIP_TYPE" = 'Joint Account'
		AND "ACCOUNT_CATEGORY" = 'Credit Card'
	GROUP BY
		1
) 
SELECT
	tl."ACCOUNT_CATEGORY",
	tc.total_customer,
	COUNT(*) AS total_customer_closed_account,
	ROUND(((COUNT(*)::DECIMAL * 100) / tc.total_customer), 2) AS closure_percentage
FROM
	transaction_line tl
JOIN total_customers tc ON
	tl."ACCOUNT_CATEGORY" = tc."ACCOUNT_CATEGORY"
WHERE
	tl."OWNERSHIP_TYPE" = 'Joint Account'
	AND tl."ACCOUNT_CATEGORY" = 'Credit Card'
	AND tl."ACCOUNT_STATUS" = 'Closed'
GROUP BY
	1,
	2;


-- Q5. Average tenure of closing months is highest for
--	Auto Loan
--	Product Loan
--	Car Loan
--	Housing Loan

-- ANS : Housing Loan 

SELECT
	"ACCOUNT_CATEGORY",
	ROUND(AVG("TENURE_MONTHS"),	2) AS avg_tenure_month
FROM
	transaction_line tl
WHERE
	"ACCOUNT_STATUS" = 'Closed'
GROUP BY
	1;










