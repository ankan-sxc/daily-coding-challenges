
----Level-1:Beginner
--Day 2:02/09/2026
--1.Count total transactions
SELECT COUNT(*) FROM paysim;
--2.Calculate total transaction amount
select sum(amount) from paysim as total_transaction_amount;
--3.Average transaction amount across all PaySim transactions.
select avg(amount) as average_transaction_amount from paysim;
--4.The number of transactions for each transaction type.
select type,
       count(*) as transaction_count 
from paysim 
group by type;
--5.Count fraudulent transactions
select type,
       count(*) as fraud_transaction_count
	   from paysim
where isFraud=1
group by type;
--6.What percentage of transactions within each transaction type are confirmed fraudulent?
SELECT
    type,
    COUNT(*) AS transaction_count,
    SUM(CASE WHEN isFraud = 1 THEN 1 ELSE 0 END) AS fraud_transaction_count,
    100.0 * SUM(CASE WHEN isFraud = 1 THEN 1 ELSE 0 END) / COUNT(*) AS fraud_rate
FROM paysim
GROUP BY type;
--7.The total monetary amount associated with confirmed fraudulent transactions for each transaction type.
select type,
       sum(amount) as total_fraud_amount
from paysim
where isFraud=1
group by type;
--8.The average transaction amount of confirmed fraudulent transactions for each transaction type.
select type,
       avg(amount) as average_fraud_amount
from paysim
where isFraud=1
group by type;
--9. Find transaction types with highest volume
select type,
       count(*) as transaction_count 
from paysim 
group by type
order by transaction_count desc;
--10.Find the transaction types with the highest average transaction amount.
select type,
       avg(amount) as average_transaction_amount 
from paysim 
group by type
order by average_transaction_amount  desc;
--Day 3: 03/09/2026
--11. Classify transactions by amount 
select step,
       type,
	   amount,
	   case 
	   when amount<1000 then 'Low'
	   when amount between 1000 and 10000 then 'Medium'
	   else 'High'
	   end as amount_category 
from paysim;
--Day5:05/09/2026 
--12.Calculate fraud rate by transaction type 
SELECT
    type,
    COUNT(*) AS transaction_count,
    SUM(CASE WHEN isFraud = 1 THEN 1 ELSE 0 END) AS fraud_transaction_count,
    100.0 * SUM(CASE WHEN isFraud = 1 THEN 1 ELSE 0 END) / COUNT(*) AS fraud_rate
FROM paysim
GROUP BY type;
--13.Compare fraudulent vs non-fraudulent transaction amounts
WITH transaction_segments AS (
    SELECT
        amount,
        CASE
            WHEN isFraud = 1 THEN 'Fraud'
            ELSE 'Non-Fraud'
        END AS fraud_status
    FROM paysim
)

SELECT
    fraud_status,
    COUNT(*) AS transaction_count,
    SUM(amount) AS total_amount,
    AVG(amount) AS average_amount
FROM transaction_segments
GROUP BY fraud_status;
---DAY-8:08/09/2026
--14.Identify transactions above a business threshold 
select step,
       type,
	   amount,
	   nameOrig,
	   nameDest,
	   isFraud
from paysim
where amount>10000
order by amount desc;
--15.Create transaction risk categories 
select
  CASE
      when amount>10000 then 'High Risk'
	  when amount between 1000 and 10000 then 'Medium Risk'
	  else 'Low Risk'
  End as risk_category,
  count(*) as transaction_count
from paysim
group by
   CASE
      when amount>10000 then 'High Risk'
	  when amount between 1000 and 10000 then 'Medium Risk'
	  else 'Low Risk'
   End 
order by transaction_count desc;
--16.Calculate fraud/non-fraud transaction counts using conditional aggregation 
select count(*) as total_transaction,
       sum(case when isFraud=1 then 1 else 0 end) as fraud_transaction,
	   sum(case when isFraud=0 then 1 else 0 end) as non_fraud_transaction
from paysim;
--17.Calculate fraud amount vs total amount 
select type,
       sum(amount) as total_amount,
	   sum(case when isFraud=1 then amount else 0 end) as fraud_amount,
	   sum(case when isFraud=0 then amount else 0 end) as non_fraud_amount
from paysim
group by type;
--18.Identify high-value fraudulent transactions
select step,
       type,
	   nameOrig,
	   nameDest,
	   amount
from paysim
where amount > 10000 and isFraud=1
order by amount desc;
--19. Find transaction types responsible for most fraud exposure 
select type,
       sum(case when isFraud=1 then 1 else 0 end) fraud_transaction_count,
	   sum(case when isFraud=1 then amount else 0 end) fraud_amount
from paysim
group by type
ORDER BY fraud_amount DESC;
--20.Mini fraud investigation: identify the most concerning transaction segment.
--For each transaction type, calculate:
--Total transactions
--Total fraud transactions
--High-value fraud transactions — isFraud = 1 AND amount > 10,000
--Total fraud amount
select type,
       count(*) as total_troupransactions,
	   sum(case when isFraud=1 then 1 else 0 end) as fraud_transactions,
	   sum(case when isFraud=1 and amount > 10000 then 1 else 0 end) as high_value_fraud_transactions,
	   sum(case when isFraud=1 then amount else 0 end) total_fraud_amount
from paysim
group by type
order by total_fraud_amount desc;
--Q.Origin-balance consistency check (TRANSFER / CASH-OUT)
SELECT
    step,
    type,
    nameOrig,
    amount,
    oldbalanceOrg,
    newbalanceOrig,
    CASE
        WHEN oldbalanceOrg - amount = newbalanceOrig
            THEN 'Consistent'
        ELSE 'Inconsistent'
    END AS origin_balance_check
FROM paysim
WHERE type IN ('TRANSFER', 'CASH_OUT');
--Q.Destination-Balance Consistency Check
SELECT
    step,
    type,
    nameOrig,
    nameDest,
    amount,
    oldbalanceDest,
    newbalanceDest,
    CASE
        WHEN oldbalanceDest + amount = newbalanceDest
            THEN 'Consistent'
        ELSE 'Inconsistent'
    END AS destination_balance_check
FROM paysim;

--Level-2: Basic Risk Analyst
-- Customer Analysis Q.21 - Q.25
--21.Find the top 10 customers (nameOrig) with the highest number of transactions.
select nameOrig,
       count(*) as transaction_count
from paysim
group by nameOrig
order by transaction_count desc
limit 10;
--22. Customers with highest transaction value
select nameOrig,
       sum(amount) as transaction_value
from paysim
group by nameOrig
order by transaction_value desc
limit 10;
--23.Customers with highest fraud count
select nameOrig,
       sum(case when isFraud=1 then 1 else 0 end) as fraud_count
from paysim
group by nameOrig
order by fraud_count desc
limit 10;
--24.Find the top 10 customers (nameOrig) with the highest total fraud amount.
select nameOrig,
       sum (case when isFraud=1 then amount else 0 end) as total_fraud_Amount
from paysim
group by nameOrig
order by total_fraud_amount desc
limit 10;
--25. Customers who have both high volume and fraud activity 
--Find customers who satisfy both conditions:
--Have made more than 100 transactions
--Have at least 1 confirmed fraudulent transaction
select nameOrig,
       count(*) as transaction_counts,
	   sum(case when isFraud=1 then 1 else 0 end) as fraudulent_transaction
from paysim
group by nameOrig 
having count(*) > 100 and sum(case when isFraud=1 then 1 else 0 end) > 0
order by fraudulent_transaction desc;
---DAY-8:09/09/2026
--Receiver analysis
--26.Receivers with highest transaction volume
--Find customers who:
--Have made more than 100 transactions :
--Have a fraud rate greater than 5% :
select nameDest,
       count(*) as transaction_count,
	   sum(case when isFraud=1 then 1 else 0 end ) as fraud_transaction,
	   100.0*sum(case when isFraud=1 then 1 else 0 end )/count(*) as fraud_rate
from paysim 
group by nameDest
having count(*) > 100.0 and 100*sum(case when isFraud=1 then 1 else 0 end )/count(*) >5
order by fraud_rate desc;
--27.Receivers receiving the highest amount 
--Find the top 10 receivers (nameDest) with the highest transaction volume.
select nameDest,
       count(*) as transaction_Count
from paysim
group by nameDest
order by transaction_count desc
limit 10;
--Day 26: 26/09/2026
--28.Receivers associated with fraud 
--Find the top 10 receivers (nameDest) with the highest number of confirmed fraud transactions.
select nameDest,
       sum(case when isFraud=1 then 1 else 0 end) as total_transaction_count
from paysim
group by nameDest
order by total_transaction_count desc
limit 10;
--29.Receiver Fraud Rate
select nameDest,
       count(*) as total_transaction_count,
	   sum(case when isFraud=1 then 1 else 0 end) as fraud_transaction_count,
	   sum(case when isFraud=1 then 1 else 0 end)*100.0/count(*) as fraud_rate
from paysim
group by nameDest
order by fraud_rate desc limit 10;
--30.High-Volume vs High-Risk Receivers
---At least 100 transactions
--Fraud rate greater than 5%
select nameDest,
       count(*) as total_transaction_count,
	   sum(case when isFraud=1 then 1 else 0 end) as fraud_transaction_count,
	   sum(case when isFraud=1 then 1 else 0 end)*100.0/count(*) as fraud_rate
from paysim
group by nameDest
having count(*)>=100 and
sum(case when isFraud=1 then 1 else 0 end)*100.0/count(*)>5;
--31.Customer Risk Segmentation
with customer_summary as
(
select nameOrig,
       count(*) as total_transaction_count,
	   sum(case when isFraud=1 then 1 else 0 end) as fraud_transaction_count,
	   sum(case when isFraud=1 then 1 else 0 end)*100.0/count(*) as fraud_rate
from paysim
group by nameOrig
)
select nameOrig,
       total_transaction_count,
	   fraud_transaction_count,
	   fraud_rate, 
	   case 
	   when fraud_rate=0 then 'Low Risk'
	   when fraud_rate > 0 and fraud_rate <=5 then 'Medium Risk'
	   else 'High Risk'
	   end as risk_segment
from customer_summary;
--32.High-Value Transaction Flags
select step,
       type,
       nameOrig,
       amount,
       isFraud,
	   case 
	   when amount > 10000 then 'High Value'
	   else 'Normal Value'
	   end as high_value_flag
from summary;
--33.Multi-Condition Fraud Rule
select type,
       amount,
	   isFraud,
	   case 
	   when type in('TRANSFER','CASH_OUT') and amount>10000 then 'Rule Hit'
	   else 'No Rule Hit' 
	   end as rule_flag
from paysim;
--34.Rule hit rate 
select count(*) as total_transactions,
SUM(
    CASE
        WHEN type IN ('TRANSFER', 'CASH_OUT')
             AND amount > 10000
        THEN 1
        ELSE 0
    END
) as rule_hit_transactions,
(SUM(
    CASE
        WHEN type IN ('TRANSFER', 'CASH_OUT')
             AND amount > 10000
        THEN 1
        ELSE 0
    END
)*100.0)/count(*) as rule_hit_rate
from paysim;
--35.Compare rule flags against isFraud
select sum(case
           when type in ('TRANSFER','CASH_OUT') and amount >10000
		   then 1 else 0 end) as total_rule_hit_transaction,
       sum(case
           when type in ('TRANSFER','CASH_OUT') and amount >10000 and isFraud=1
		   then 1 else 0 end) rule_hit_fraud_transactions,
	   (sum(case
           when type in ('TRANSFER','CASH_OUT') and amount >10000 and isFraud=1
		   then 1 else 0 end)*100.0)/sum(case
           when type in ('TRANSFER','CASH_OUT') and amount >10000
		   then 1 else 0 end) as rule_hit_fraud_rate
from paysim;
--36.False positives 
with rule_hits as
(
select isFraud,
       case 
       when type in ('TRANSFER','CASH_OUT') and amount> 10000 then 1 else 0
	   end as rule_hit_flag
	   from paysim
)
select sum(rule_hit_flag) as total_rule_hit_transactions,
       sum (case when rule_hit_flag=1 and isFraud=0 then 1 else 0 end) as false_positive,
	   (sum (case when rule_hit_flag=1 and isFraud=0 then 1 else 0 end)*100.0)/nullif(sum(rule_hit_flag),0)as false_positive_rate
	   from rule_hits;
--37.False Negative
WITH rule_hits AS
(
    SELECT
        isFraud,
        CASE
            WHEN type IN ('TRANSFER', 'CASH_OUT')
                 AND amount > 10000
            THEN 1
            ELSE 0
        END AS rule_hit_flag
    FROM paysim
)
SELECT
    SUM(CASE WHEN isFraud = 1 THEN 1 ELSE 0 END)
        AS total_fraud_transactions,

    SUM(
        CASE
            WHEN isFraud = 1
                 AND rule_hit_flag = 0
            THEN 1
            ELSE 0
        END
    ) AS false_negative_transactions,

    SUM(
        CASE
            WHEN isFraud = 1
                 AND rule_hit_flag = 0
            THEN 1
            ELSE 0
        END
    ) * 100.0
    / NULLIF(
        SUM(CASE WHEN isFraud = 1 THEN 1 ELSE 0 END),
        0
    ) AS false_negative_rate

FROM rule_hits;
--38.Fraud Capture Rate
--How much of the actual fraud does our rule successfully capture?
WITH fraud_metrics AS (
    SELECT
        COUNT(*) FILTER (
            WHERE isFraud = 1
        ) AS total_actual_fraud,

        COUNT(*) FILTER (
            WHERE isFraud = 1
              AND type IN ('TRANSFER', 'CASH_OUT')
              AND amount > 10000
        ) AS fraud_captured
    FROM paysim
)
SELECT
    total_actual_fraud,
    fraud_captured,
    ROUND(
        100.0 * fraud_captured
        / NULLIF(total_actual_fraud, 0),
        2
    ) AS fraud_capture_rate_percent
FROM fraud_metrics;
--39.Rule performance by transaction type
WITH rule_performance AS (
    SELECT
        type,
        COUNT(*) AS total_transactions,

        COUNT(*) FILTER (
            WHERE isFraud = 1
        ) AS actual_fraud,

        COUNT(*) FILTER (
            WHERE type IN ('TRANSFER', 'CASH_OUT')
              AND amount > 10000
        ) AS rule_hits,

        COUNT(*) FILTER (
            WHERE isFraud = 1
              AND type IN ('TRANSFER', 'CASH_OUT')
              AND amount > 10000
        ) AS fraud_captured

    FROM paysim
    GROUP BY type
)
SELECT
    type,
    total_transactions,
    actual_fraud,
    rule_hits,
    fraud_captured,

    ROUND(
        100.0 * fraud_captured
        / NULLIF(actual_fraud, 0),
        2
    ) AS fraud_capture_rate_percent

FROM rule_performance
ORDER BY fraud_capture_rate_percent DESC NULLS LAST;
--40. Explain whether a rule is actually useful 
WITH rule_evaluation AS (
    SELECT
        type,
        COUNT(*) AS total_transactions,

        COUNT(*) FILTER (
            WHERE isFraud = 1
        ) AS actual_fraud,

        COUNT(*) FILTER (
            WHERE type IN ('TRANSFER', 'CASH_OUT')
              AND amount > 10000
        ) AS rule_hits,

        COUNT(*) FILTER (
            WHERE isFraud = 1
              AND type IN ('TRANSFER', 'CASH_OUT')
              AND amount > 10000
        ) AS true_positives,

        COUNT(*) FILTER (
            WHERE isFraud = 0
              AND type IN ('TRANSFER', 'CASH_OUT')
              AND amount > 10000
        ) AS false_positives,

        SUM(amount) FILTER (
            WHERE isFraud = 1
              AND type IN ('TRANSFER', 'CASH_OUT')
              AND amount > 10000
        ) AS fraud_value_captured

    FROM paysim
    GROUP BY type
)
SELECT
    type,
    total_transactions,
    actual_fraud,
    rule_hits,
    true_positives,
    false_positives,

    ROUND(
        100.0 * true_positives
        / NULLIF(actual_fraud, 0), 2
    ) AS fraud_capture_rate_pct,

    ROUND(
        100.0 * true_positives
        / NULLIF(rule_hits, 0), 2
    ) AS precision_pct,

    ROUND(
        100.0 * false_positives
        / NULLIF(rule_hits, 0), 2
    ) AS false_positive_rate_among_alerts_pct,

    COALESCE(fraud_value_captured, 0) AS fraud_value_captured

FROM rule_evaluation
ORDER BY fraud_value_captured DESC;
--Date:10/10/2026
--LEVEL 3 — Intermediate Risk Analyst
--41.Customer-level transaction summary 
select nameOrig,
       count(*) as total_transactions,
	   sum(amount) as total_transaction_amount,
	   avg(amount) as average_transaction_amount,
	   sum (case when isFraud=1 then 1 else 0 end) as fraud_transaction_count,
	   min(step) as first_transaction_step,
	   max(step) as last_transaction_step
from paysim
group by nameOrig;
--42.Customer Fraud Summary
select nameOrig,
       sum(case
	          when isFraud=1 then 1 else 0
		   end
		   ) as total_fraud_transaction_count,
	   sum(case 
	          when isFraud=1 then amount else 0
		   end
	      ) as total_fruad_amount,
	   avg(case 
	          when isFraud=1 then amount else NULL
	       end 
		   ) as average_fraud_amount,
		max(case 
		       when isFraud=1 then step else null
		    end
			) as latest_fraud_step
from paysim
group by nameOrig;
--43.Question 43 — Customer Risk Profile
with customer_metrics as(
select nameOrig,
       count(*) as total_transactions,
	   
)
	   