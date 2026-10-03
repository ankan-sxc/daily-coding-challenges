--Date: October 1,2026
--Intermediate — Aggregation, Subqueries, Window Functions, Anomaly Detection 
--Q.1: For each account, flag transactions where the amount is more than 3× that account's
--own average transaction amount.
select nameOrig,
       amount,
	   avg(amount) over(partition by nameOrig) as account_avg_amount,
	   case
	      when amount>3*AVG(amount) OVER (PARTITION BY nameOrig) then 'Flag'
		  else 'Normal'
		end as transaction_flag
from paysim;
--Q.2:Running total of CASH_OUT amount per account, ordered by step .
select nameOrig,
       step,
	   amount,
	   sum(amount) over (partition by nameOrig order by step rows between unbounded preceding and current row) as running_total_amount
from paysim
where type='CASH_OUT';
--Q.3: Find accounts making more than 5 transactions within the same step
select nameOrig,
       step,
	   count(*) as transaction_count
from paysim
group by  nameOrig,Step
having count(*) >5;
--Q.4: For each transaction, find how many steps passed since that account's previoustransaction;
--flag gaps under 2 steps as high-velocity.
with transaction_gaps as 
(select nameOrig,
       step,
	   lag(step,) over (partition by nameOrig order by step) as previous_step
from paysim
)
select nameOrig,
       step,
	   previous_step,
	   step - previous_step as step_gap,
	   case 
	      when step - previous_step < 2 then 'High Velocity'
		  else 'Normal'
	   end as velocity_flag
from transaction_gaps;
--5. Find the top 1% of transactions by amount, without hardcoding a dollar threshold
with ranked_transactions as
(select nameOrig,
       amount,
	   type,
	   isFraud,
	   percent_rank() over (order by amount) as percent_rank
from paysim)
select * from ranked_transactions
where percent_rank>0.99 and isFraud=1;
--6.Find transactions where the amount exceeds that account's own average — using a
--correlated subquery this time, not a window function
select p1.nameOrig,
       p1.type, 
	   p1.isFraud,
	   p1.amount 
from paysim p1
where p1.amount>(
select avg(p2.amount) from paysim p2 where p1.nameOrig=p2.nameOrig
);
--Another approach
WITH account_avg AS (
    SELECT
        nameOrig,
        AVG(amount) AS avg_amount
    FROM paysim
    GROUP BY nameOrig
)
SELECT
    p.nameOrig,
    p.type,
    p.isFraud,
    p.amount,
    a.avg_amount
FROM paysim p
JOIN account_avg a
    ON p.nameOrig = a.nameOrig
WHERE p.amount > a.avg_amount;
--Q.7:Detect structuring: accounts sending 3+ transactions each between 180,000
--199,999 (just under the flagging threshold) within a short window
with qualifying_transaction as
(select nameOrig,
       step,
	   amount,
	   type,
	   isFraud,
	   count(*) as qualifying_transactions
from paysim 
where amount>=180000 and amount < 200000),
transaction_gaps as
(
select nameOrig,
       step,
	   amount,
	   type,
	   isFraud,
	   lag(step) over (partition by namOrig order by step) as previous_steps
from qualifying_transactions
)
select nameOrig,
       step,
	   amount,
	   type,
	   isFraud,
	   previous_steps,
	   step - previous_steps as step_gap
from transaction_gaps;



--Q.8:.Fraud rate (share of transactions that are fraudulent) by transaction type. 
SELECT
    type,
    AVG(isFraud::numeric) AS fraud_rate
FROM paysim
GROUP BY type;
--Q.9:.Find transactions where the recorded balances don't reconcile: 
-- oldbalanceOrg - amount <> newbalanceOrig .
select nameOrig,
       type,
	   amount,
	   oldbalanceOrg,
	   newbalanceOrig,
	   isFraud
from paysim 
where oldbalanceOrg - amount <> newbalanceOrig;
--Q.10:For each account, return only its single largest transaction. 
