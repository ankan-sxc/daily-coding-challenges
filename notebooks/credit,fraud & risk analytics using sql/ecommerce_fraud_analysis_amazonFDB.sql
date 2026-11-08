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
SELECT CASE
          WHEN u.age < 25 THEN 'Early 20s'
		  WHEN u.age between 25 and < 40 THEN 'Mid 40s'
		  when u.age between 40 and < 60 THEN 'Late 40s'
		  else 'Senior Citizen'
	   END as age_bands,
	   count(transaction_id)as total_transactions,
	   sum(case when t.class=1 then 1 else 0 end) as total_fraud_transactions,
	   (100.0*sum(case when t.class=1 then 1 else 0 end))/nullif(count(*),0) as fraud_rate
	   
FROM transactions AS t

INNER JOIN users AS u
ON t.user_id=u.user_id
GROUP BY
       CASE
          WHEN u.age < 25 THEN 'Early 20s'
		  WHEN u.age between 25 and < 40 THEN 'Mid 40s'
		  when u.age between 40 and < 60 THEN 'Late 40s'
		  else 'Senior Citizen'
	   END as age_bands,

ORDER BY age_bands;



    