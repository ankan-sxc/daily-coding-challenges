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