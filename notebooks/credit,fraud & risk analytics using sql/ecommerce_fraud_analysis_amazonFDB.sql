--Date: 02/11/2026
--Intermediate (Q1–Q40)
--Q1. List each transaction with its merchant name and product category for orders above $500.
SELECT
    t.transaction_id,
    COALESCE(m.merchant_name, 'UNKNOWN MERCHANT') AS merchant_name,
    t.product_category,
    t.purchase_value
FROM transactions t
LEFT JOIN (
    SELECT
        merchant_id,
        MIN(merchant_name) AS merchant_name
    FROM merchants
    GROUP BY merchant_id
) m
    ON t.merchant_id = m.merchant_id
WHERE t.purchase_value > 500
ORDER BY t.purchase_value DESC;
--Q2.Find transactions where the first payment attempt was declined but a later attempt
--on the same transaction was approved.
SELECT p1.transaction_id,
       -- First attempt details
       p1.payment_id,
       p1.attempt_no,
       p1.payment_status,
       p1.attempted_at,

    -- Subsequent attempt details
       p2.payment_id,
       p2.attempt_no,
       p2.payment_status,
       p2.attempted_at

FROM payments AS p1
INNER JOIN payments AS p2 ON p1.transaction_id=p2.transaction_id 
                             and p2.attempt_no>p1.attempt_no
        

WHERE p1.attempt_no=1 and p1.payment_status='declined' and p2.payment_status='approved'
ORDER BY p1.transaction_id,
         p1.attempted_at;
--Edge Case 1: Multiple approved attempts
--A transaction has multiple approved payment attempts. 
--Avoid reporting duplicate transaction-level investigation records.
WITH qualifying_attempts AS (
SELECT p1.transaction_id,
-- First declined attempt
       p1.payment_id as first_payment_id,
	   p1.attempt_no as first_attempt_no,
	   p1.payment_status as first_payment_status,
	   p1.attempted_at as first_attempted_at,
-- Subsequent approved attempt
       p2.payment_id as approved_payment_id,
	   p2.attempt_no as approved_attempt_no,
	   p2.payment_status as approved_payment_status,
	   p2.attempted_at as approved_attempted_at
FROM payments p1
INNER JOIN payments p2 ON p1.transaction_id=p2.transaction_id
                      and p2.attempt_no>p1.attempt_no
WHERE p1.payment_status='declined' and p2.payment_status='approved'
),
ranked_approvals AS (
SELECT *,
       ROW_NUMBER() OVER (PARTITION BY transaction_id
                          ORDER BY approved_attempt_no,
						           approved_attempted_at,
								   approved_payment_id
                         ) AS rn

FROM qualifying_attempts
)
SELECT *
FROM ranked_approvals
WHERE rn=1;
--Edge Case 2: Duplicate attempt numbers
WITH duplicate_attempts AS (
SELECT transaction_id,
       attempt_no,
	   COUNT(*) AS attempt_record_count
        -- Transaction ID
        -- Attempt number
FROM payments
GROUP BY transaction_id,
         attempt_no
HAVING count(*) > 1
)

SELECT
    p.*
FROM payments p
INNER JOIN duplicate_attempts d
ON p.transaction_id=d.transaction_id
and p.attempt_no=d.attempt_no
-- Match attempt number
ORDER BY p.transaction_id,
         p.attempt_no,
		 p.attempted_at;
--Edge Case-3:Timestamp and attempt-number inconsistencies
SELECT
    p1.transaction_id,
	-- First attempt number
	p1.attempt_no as first_attempt_no,
    -- First attempt timestamp
	p1.attempted_at as first_attempted_at,
    -- Subsequent attempt number
	p2.attempt_no as subsequent_attempt_no,
    -- Subsequent attempt timestamp
	p2.attempted_at as subsequent_attempt_at
FROM payments p1
INNER JOIN payments p2
ON p1.transaction_id=p2.transaction_id
and p1.attempt_no>p2.attempted_no 
WHERE p1.attempt_no = 1 AND p2.attempted_at < p1.attempted_at
ORDER BY p1.transaction_id,
         p2.attempt_no;


--Date:08/11/2026
--Q3.For each signup source, show total transactions and total fraud transactions.
select u.source,
       count(t.transaction_id) as total_transactions,
	   sum(case when t.class=1 then 1 else 0 end) as total_fraud_transactions
from transactions t
left join users u
on t.user_id=u.user_id
group by u.source
order by total_fraud_transactions;
--Q4.List transactions with no matching refund whose merchant's refund rate exceeds 20%. 
WITH merchant_refund_rate AS (
SELECT t.merchant_id,
	   count(distinct t.transaction_id) as total_distinct_txn,
	   count(distinct r.transaction_id) as total_refunded_txn,
	   100.0*count(distinct r.transaction_id)/nullif(count(distinct t.transaction_id),0) as refund_rate

FROM transactions AS t
left join refunds r on t.transaction_id=r.transaction_id
GROUP BY
        t.merchant_id
)
SELECT
    t.transaction_id,
    m.merchant_id,
	m.merchant_name,
	mr.refund_rate
    
FROM transactions AS t
inner join merchant_refund_rate mr on t.merchant_id=mr.merchant_id
left join refunds r on t.transaction_id=r.transaction_id
left join merchants m on t.merchant_id=m.merchant_id
WHERE r.refund_id is null and mr.refund_rate > 20
ORDER BY mr.refund_rate desc;
--Q5.Show every transaction with device type and OS, flagging rows where no match in devices.
SELECT t.transaction_id,
       d.device_id,
	   d.device_type,
	   d.os,
	   CASE 
	      WHEN t.device_id IS NULL THEN 'MISSING DEVICE ID '
          WHEN d.device_id IS NULL THEN 'Orphaned Device'
          ELSE 'Matched'
       END AS device_flag

FROM transactions AS t
LEFT JOIN devices AS d
ON t.device_id=d.device_id
ORDER BY t.transaction_id desc;
--Q6.Fraud rate (fraud / total ) by product_category sorted descending.
SELECT product_category,
       count(*) as total_txn,
	   sum(case when class=1 then 1 else 0 end) as total_fraud_txn,
	   (100.0*sum(case when class=1 then 1 else 0 end))/nullif(count(*),0) as fraud_rate
    
FROM transactions
GROUP BY product_category
ORDER BY fraud_rate desc;
--Q7.Average product_category,purchase_value and fraud count by payment_method .
SELECT payment_method,
       product_category,
	   avg(purchase_value) as average_purchase_value,
	   sum(case when class=1 then 1 else 0 end) as total_fraud_transactions
    
FROM transactions
GROUP BY payment_method,
         product_category

ORDER BY payment_method,
         average_purchase_value desc;
--Q8.Bucket users into age bands (<25, 25–40, 40–60, 60+) and show fraud rate per band.
WITH age_segmented AS (
    SELECT
        t.transaction_id,
        t.class,

        CASE
            WHEN u.age IS NULL THEN 'Unknown'
            WHEN u.age < 0 THEN 'Invalid Age'
            WHEN u.age < 25 THEN 'Under 25'
            WHEN u.age < 40 THEN '25-39'
            WHEN u.age < 60 THEN '40-59'
            ELSE '60+'
        END AS age_bands

    FROM transactions AS t

    INNER JOIN users AS u
        ON t.user_id = u.user_id
),

fraud_by_age AS (
    SELECT
        age_bands,

        COUNT(transaction_id) AS total_transactions,

        SUM(
            CASE WHEN class = 1 THEN 1 ELSE 0 END
        ) AS total_fraud_transactions,

        ROUND(
            100.0 * SUM(
                CASE WHEN class = 1 THEN 1 ELSE 0 END
            ) / NULLIF(COUNT(*), 0),
            2
        ) AS fraud_rate

    FROM age_segmented

    GROUP BY age_bands
)

SELECT *
FROM fraud_by_age

ORDER BY
    CASE
        WHEN age_bands = 'Under 25' THEN 1
        WHEN age_bands = '25-39' THEN 2
        WHEN age_bands = '40-59' THEN 3
        WHEN age_bands = '60+' THEN 4
        WHEN age_bands = 'Unknown' THEN 5
        WHEN age_bands = 'Invalid Age' THEN 6
    END;
--Date:09/11/2026
--Q9.Top 10 merchants by total refund amount in the trailing 90 days.
SELECT t.merchant_id,
       m.merchant_name,
	   sum(r.refund_amount) as total_refund_amount
FROM refunds AS r
inner join transactions t on r.transaction_id=t.transaction_id
left join merchants m on t.merchant_id=m.merchant_id
Where r.refunded_at >= CURRENT_TIMESTAMP - INTERVAL '90 days' AND r.refunded_at <= CURRENT_TIMESTAMP
GROUP BY t.merchant_id,
         m.merchant_name
ORDER BY total_refund_amount desc nulls last,
         t.merchant_id asc
LIMIT 10;
--Q10.Fraud rate by country, restricted to countries with 500+ transactions.
SELECT m.country,
       COUNT(t.transaction_id) AS total_transactions,
       SUM(CASE WHEN t.class = 1 THEN 1 ELSE 0 END) AS total_fraud_transactions,
	   ROUND(100.0 * SUM(CASE WHEN t.class = 1 THEN 1 ELSE 0 END) / NULLIF(COUNT(t.transaction_id), 0), 2) AS fraud_rate
FROM transactions AS t
INNER JOIN merchants AS m
    ON t.merchant_id = m.merchant_id
GROUP BY
    m.country
HAVING
    COUNT(t.transaction_id) >= 500
ORDER BY
    fraud_rate DESC;
--Date:10/11/2026
--Q11:For each device_type , count distinct users and fraud rate.
SELECT d.device_type,
       count(distinct t.user_id) as total_distinct_users,
	   count(t.transaction_id) as total_transaction_id,
	   sum(case when t.class=1 then 1 else 0 end) as total_fraudulent_txn,
	   round((100.0*sum(case when t.class=1 then 1 else 0 end))/nullif(count(transaction_id),0),2) as fraud_rate
FROM transactions AS t
INNER JOIN devices d 
on t.device_id=d.device_id
GROUP BY d.device_type
ORDER BY fraud_rate;
--Q12.Monthly fraud-rate trend for 2026: year-month, fraud_count, total_count, fraud_rate.
SELECT date_trunc('month',purchase_time) as month_of_purchase,
       sum(case when class=1 then 1 else 0 end) as total_fraudulent_txn,
	   count(*) as total_fraud_txn,
	   round((100.0*sum(case when class=1 then 1 else 0 end))/nullif(count(*),0),2) as fraud_rate
FROM transactions AS t
WHERE purchase_time >= TIMESTAMP '2026-01-01'AND purchase_time < TIMESTAMP '2027-01-01'
GROUP BY date_trunc('month',purchase_time) 
ORDER BY month_of_purchase;
--Q.13: Find users whose total spend exceeds the platform's average spend-per-user.
SELECT user_id,
       SUM(purchase_value) AS total_spend
FROM transactions
WHERE user_id IS NOT NULL
GROUP BY user_id
HAVING SUM(purchase_value) > (SELECT AVG(total_spend)
                              FROM (SELECT user_id,
                                   SUM(purchase_value) AS total_spend
								   FROM transactions
                                   WHERE user_id IS NOT NULL
								   GROUP BY user_id) AS user_spending)
ORDER BY total_spend DESC;
--Q.14:Flag transactions where purchase_value is more than 3× that user's own historical average. 
WITH historical_spending AS (
SELECT  t1.transaction_id,
        t1.user_id,
        t1.purchase_time,
        t1.purchase_value,
        (
            SELECT AVG(t2.purchase_value)
            FROM transactions AS t2
            WHERE t2.user_id = t1.user_id AND t2.purchase_time < t1.purchase_time
        ) AS historical_avg
FROM transactions AS t1
)
SELECT transaction_id,
       user_id,
       purchase_time,
       purchase_value,
       ROUND(historical_avg, 2) AS historical_avg,
       CASE
          WHEN historical_avg IS NULL THEN 'Insufficient History'
          WHEN purchase_value > 3 * historical_avg THEN 'Flagged'
          ELSE 'Normal'
       END AS anomaly_flag
FROM historical_spending
ORDER BY user_id, 
         purchase_time;
--Q.15: List merchants whose refund rate exceeds the platform-wide average refund rate.
SELECT t.merchant_id,
       m.merchant_name,
       COUNT(DISTINCT t.transaction_id) AS total_transactions,
       COUNT(DISTINCT r.transaction_id) AS refunded_transactions,
	   ROUND(100.0 * COUNT(DISTINCT r.transaction_id)
        / NULLIF(COUNT(DISTINCT t.transaction_id), 0),2) AS refund_rate
FROM transactions AS t
LEFT JOIN refunds AS r
     ON t.transaction_id = r.transaction_id
LEFT JOIN merchants AS m
     ON t.merchant_id = m.merchant_id
GROUP BY t.merchant_id,
    m.merchant_name

HAVING
    1.0 * COUNT(DISTINCT r.transaction_id)
    / NULLIF(COUNT(DISTINCT t.transaction_id), 0)
    >
    (
        SELECT
            1.0 * COUNT(DISTINCT r2.transaction_id)
            / NULLIF(COUNT(DISTINCT t2.transaction_id), 0)

        FROM transactions AS t2

        LEFT JOIN refunds AS r2
             ON t2.transaction_id = r2.transaction_id
    )

ORDER BY refund_rate DESC;
--Date:12/11/2026
--Q16. Find users who signed up in the last 7 days whose first transaction value sits in the
--top 1% platform-wide. 
WITH platform_threshold AS 
(
SELECT
     percentile_cont(0.99) within group (order by purchase_value) as percentile_99
FROM transactions
),

ranked_transactions AS 
(
SELECT  t.transaction_id,
        t.user_id,
        t.purchase_time,
        t.purchase_value,
		row_number() over (partition by t.user_id order by t.purchase_time asc null last,t.transaction_id asc) as rank_purchase_time
FROM transactions AS t
WHERE t.user_id IS NOT NULL
),
first_transactions 
AS 
(
SELECT *
FROM ranked_transactions
WHERE rank_purchase_time=1
)

SELECT u.user_id,
       u.signup_time,
	   ft.transaction_id,
	   ft.purchase_value
FROM users AS u
INNER JOIN first_transactions AS ft
    ON u.user_id = ft.user_id
CROSS JOIN platform_threshold AS p
WHERE u.signup_time >= CURRENT_TIMESTAMP - INTERVAL '7 days'
  AND ft.purchase_time >= u.signup_time
  AND u.signup_time <= CURRENT_TIMESTAMP
  AND ft.purchase_value >= p.percentile_99
ORDER BY ft.purchase_value desc;
--Date:13/11/2026
--Q.17:Identify transactions from an ip_address also used by 3+ other distinct 
--distinct user_id.
SELECT transaction_id,
       user_id,
	   ip_address,
	   purchase_time,
	   purchase_value
FROM transactions AS t
WHERE t.ip_address IN 
(
SELECT ip_address
FROM transactions
WHERE ip_address is not null
GROUP BY ip_address
HAVING count(distinct user_id )>= 4
)
ORDER BY ip_address,purchase_time;
--Q.18: Find users flagged fraud (class = 1) whootherwise have 10+ prior clean, approved transactions — 
--candidates for false-positive review. 
WITH flagged_transactions AS (
 SELECT
        t1.user_id,
        t1.transaction_id AS flagged_transaction_id,
        t1.purchase_time AS flagged_at,
        t1.purchase_value,

        (
            SELECT COUNT(*)
            FROM transactions AS t2
            WHERE t2.user_id = t1.user_id
              AND t2.purchase_time < t1.purchase_time
              AND t2.class = 0
              AND EXISTS (
                  SELECT 1
                  FROM payments AS p
                  WHERE p.transaction_id = t2.transaction_id
                    AND p.payment_status = 'approved'
                    AND p.attempted_at < t1.purchase_time
              )
        ) AS prior_clean_approved_count

    FROM transactions AS t1

    WHERE t1.class = 1
      AND NOT EXISTS (
          SELECT 1
          FROM transactions AS t3
          WHERE t3.user_id = t1.user_id
            AND t3.purchase_time < t1.purchase_time
            AND t3.class = 1
      )
)

SELECT
    user_id,
    flagged_transaction_id,
    flagged_at,
    purchase_value,
    prior_clean_approved_count

FROM flagged_transactions

WHERE prior_clean_approved_count >= 10

ORDER BY flagged_at DESC;
--Q.19:For each user, compute the gap in minutes betweenconsecutive transactions.
WITH transaction_history AS (
    SELECT
        t.user_id,
        t.transaction_id,
        t.purchase_time,
        t.purchase_value,

        LAG(t.purchase_time) OVER (
            PARTITION BY t.user_id
            ORDER BY t.purchase_time, t.transaction_id
        ) AS previous_purchase_time

    FROM transactions AS t
    WHERE t.purchase_time IS NOT NULL
)

SELECT
    user_id,
    transaction_id,
    purchase_time,
    previous_purchase_time,

    ROUND(
        EXTRACT(
            EPOCH FROM (purchase_time - previous_purchase_time)
        ) / 60.0,
        2
    ) AS gap_minutes

FROM transaction_history

ORDER BY
    user_id,
    purchase_time,
    transaction_id;
--Q.20: Rank each user's transactions by purchase_value descending. 
SELECT
    user_id,
    transaction_id,
    purchase_value,
    purchase_time,
	rank() over (partition by user_id order by purchase_value desc) as purchase_value_rank
FROM transactions
ORDER BY
    user_id,
    purchase_value_rank,
    transaction_id;
--Q.21:7-day rolling sum of transaction count and value per user.
SELECT
    user_id,
    transaction_id,
    purchase_time,
    purchase_value,
	count(*) over (partition by user_id order by purchase_time range between interval '7 days' preceding 
	and current row) as rolling_7d_transaction_count,
	sum(purchase_value) over (partition by user_id order by purchase_time range between interval '7 days' preceding 
	and current row) as rolling_7d_purchase_amount
FROM transactions
WHERE purchase_time IS NOT NULL
ORDER BY user_id,
         purchase_time,
         transaction_id;
--Q.22: For each merchant, compute each transaction's percentile rank by value to surface outliers. 
SELECT
    merchant_id,
    transaction_id,
    purchase_time,
    purchase_value,
	percent_rank() over (partition by merchant_id order by purchase_value ) as transaction_percentile_rank
FROM transactions
WHERE purchase_value IS NOT NULL
ORDER BY
    merchant_id,
    transaction_percentile_rank DESC,
    transaction_id;
--Q.23: Find each user's first transaction and compare its value to how old the account was at that purchase.
WITH ranked_transactions AS 
(
SELECT  t.user_id,
        t.transaction_id,
        t.purchase_time,
        t.purchase_value,
		row_number() over (partition by t.user_id order by t.purchase_time,t.transaction_id) as ranked_txn
FROM transactions AS t
WHERE t.purchase_time IS NOT NULL
)
SELECT
    u.user_id,
    u.signup_time,
    rt.transaction_id AS first_transaction_id,
    rt.purchase_time AS first_purchase_time,
    rt.purchase_value AS first_purchase_value,
	round(extract(epoch from (rt.purchase_time - u.signup_time))/3600.0,2) as account_age_hours

FROM ranked_transactions AS rt
INNER JOIN users AS u
    ON rt.user_id = u.user_id
WHERE rt.ranked_txn=1
ORDER BY u.user_id;
--Q.24:Running (cumulative) fraud rate ordered by date
WITH daily_summary AS 
(
SELECT  purchase_time::date AS d,
        COUNT(*) AS daily_transactions,
        COUNT(*) FILTER (WHERE class = 1) AS daily_fraud
FROM transactions
WHERE purchase_time IS NOT NULL
GROUP BY purchase_time::date
),
cumulative_summary AS 
(
SELECT d,
       SUM(daily_transactions) OVER (ORDER BY d ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_transactions,
	   SUM(daily_fraud) OVER (ORDER BY d ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_fraud
FROM daily_summary
)
SELECT
    d AS transaction_date,
    cumulative_transactions,
    cumulative_fraud,
	ROUND(100.0 * cumulative_fraud/ NULLIF(cumulative_transactions, 0),2 ) AS cumulative_fraud_rate_pct
FROM cumulative_summary
ORDER BY transaction_date;
--Q.25:Flag users with 5+ transactions in any rolling 1-hour window.
-- Q25: Flag users with 5+ transactions in a rolling 1-hour window
WITH transaction_velocity AS 
(
SELECT user_id,
       transaction_id,
       purchase_time,
       purchase_value,
       COUNT(*) OVER (PARTITION BY user_id ORDER BY purchase_time RANGE BETWEEN INTERVAL '1 hour' PRECEDING
                      AND CURRENT ROW) AS txn_count_1h
FROM transactions
WHERE purchase_time IS NOT NULL  AND user_id IS NOT NULL
)
SELECT
    user_id,
    transaction_id,
    purchase_time,
    purchase_value,
    txn_count_1h,
    'High Velocity' AS velocity_flag
FROM transaction_velocity
WHERE txn_count_1h >= 5
ORDER BY user_id,
         purchase_time,
         transaction_id;












    