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
--Date: 05/10/2026
--Q.10:For each account, return only its single largest transaction. 
with ranked_transactions as 
(
select nameOrig,
       amount,
	   type,
	   step, 
	   isFraud,
	   row_number() over (partition by nameOrig order by amount desc) as rnk_transaction
from paysim
)
select * from ranked_transactions
where rnk_transaction=1;
--11.Compute the average gap (in steps) between an account's consecutive transactions — a
--per-account "normal velocity" baseline. 
with transaction_velocity as
(
select nameOrig,
       step,
	   lag(step) over (partition by nameOrig Order By step) as previous_step
from paysim
)
select nameOrig,
       avg(step-previous_step) as Average_Step_Gap
from transaction_velocity
group by nameOrig;
--12. Find TRANSFER s immediately followed by a CASH_OUT from the same account,
--one step later — the canonical PaySim fraud chain.
with transaction_sequence as
(
select nameOrig,
       step,
	   type, 
	   amount,
	   lead(step) over (partition by nameOrig order by step) as next_step,
	   lead (type) over (partition by nameOrig Order by step) as next_type,
	   lead(amount) over (partition by nameOrig order by step) as next_amoiunt
from paysim
)
select * from transaction_sequence
where type= 'TRANSFER' and next_type = 'CASH_OUT' and  next_step=step+1;
--13.Compute a z-score for each transaction's amount relative to its own type, and return
--anything with |z| > 3.
with z_score_calculation as(
select amount,
       avg(amount) over (partition by type) as type_avg,
       stddev(amount) over (partition by type) as type_std
from paysim
)
select amount,
       (amount - type_avg)/type_std as z_score
from z_score_calculation
where abs((amount - type_avg)/type_std)>3;
--14. Find accounts with 3 or more transactions where amount > oldbalanceOrg :
--repeated attempts that should have failed on insufficient funds.
SELECT
    nameOrig,
    COUNT(*) AS insufficient_funds_attempts
FROM paysim
WHERE amount > oldbalanceOrg
GROUP BY nameOrig
HAVING COUNT(*) >= 3
ORDER BY insufficient_funds_attempts DESC;
--15.Using a CTE, isolate WHERE amount > TRANSFER s over 100,000, 
--then find which of those destinationaccounts went on to CASH_OUT .
WITH large_transfers AS
(
    SELECT
        nameOrig,
        nameDest,
        step,
        amount
    FROM paysim
    WHERE type = 'TRANSFER'
      AND amount > 100000
)
SELECT
    l.nameOrig AS transfer_sender,
    l.nameDest AS destination_account,
    l.step AS transfer_step,
    l.amount AS transfer_amount,
    p.step AS cashout_step,
    p.amount AS cashout_amount
FROM large_transfers l
JOIN paysim p
    ON l.nameDest = p.nameOrig
WHERE p.type = 'CASH_OUT'
  AND p.step > l.step
ORDER BY l.step, p.step;
--16. For each step , what share of transactions are CASH_OUT vs. everything else? 
select step,
       count(*) as total_transactions,
	   sum (case when type='CASH_OUT' then 1 else 0 end) as cashout_transactions,
	   sum (case when type='CASH_OUT' then 1 else 0 end)/ count(*) as cashou_share
from paysim
group by step;
--17. Median transaction amount per type
select type,
       percentile_cont(0.5) within group (order by amount) as meadian_amount
from paysim
group by type;
/*18. Debugging:Fix this — meant to show each account alongside its average transaction amount:
SELECT nameOrig, amount, AVG(amount)
FROM transactions
GROUP BY nameOrig;*/
select nameOrig,
       amount,
	   avg(amount) over (partition by nameOrig ) as average_transaction_amount
from paysim;
/*
19.Debugging: Fix this - meant to flag accounts with more than 10 transactions:
SELECT nameOrig, COUNT(*) AS txn_count
FROM transactions
WHERE COUNT(*) > 10
GROUP BY nameOrig
*/
select nameOrig,
       count(*) as txn_count
from paysim
group by nameOrig
having count(*)>3;
/*20.Debugging: This is meant to rank each account's transactions by amount, but every
row comes back ranked 1:
SELECT nameOrig, amount,
RANK() OVER (PARTITION BY nameOrig) AS amt_rank
FROM transactions;
*/
SELECT nameOrig, 
       amount,
       RANK() OVER (PARTITION BY nameOrig order by amount) AS amt_rank
FROM paysim;
--Date: 07/10/2026
--LEVEL: Advanced - Fraud Chains, Multi-Signal Risk, Scale
--21.Using a recursive CTE, trace transaction chains up to 3 hops (A→B→C): an account
--receives, then forwards.


























--22.Identify possible mule accounts: high fan-in (many distinct senders) followed by a
--fast, near-total cash-out.
wi














--23.Flag accounts with 3+ over-limit attempts (amount > oldbalanceOrg ) inside any
--rolling 24-step window.
with over_limit_txn as(
select nameOrig,
       step,
	   amount,
	   oldbalanceOrg
from paysim
where amount > oldbalanceOrg
),
rolling_counts as
(select nameOrig,
       step,
       count(*) over (partition by nameOrig order by step 
	                  range between 24 preceding and current row ) as rolling_count
from over_limit_txn
)
select nameOrig,
       step,
	   rolling_count
from rolling_counts
where rolling_count>=3;
--24.Identify high-risk merchants: destinations that receive disproportionately often
--from accounts with a fraud history, even though the merchant itself is never isFraud = 1 
-- Identify high-risk destination accounts
WITH fraud_history_senders AS (
    SELECT DISTINCT nameOrig
    FROM paysim
    WHERE isFraud = 1
),

fraud_history_exposure AS (
    SELECT
        p.nameDest AS destination_account,
        COUNT(*) AS suspicious_transaction_count,
        COUNT(DISTINCT f.nameOrig) AS distinct_fraud_history_senders,
        SUM(p.amount) AS suspicious_incoming_amount
    FROM paysim p
    JOIN fraud_history_senders f
        ON p.nameOrig = f.nameOrig
    GROUP BY p.nameDest
),

total_incoming AS (
    SELECT
        nameDest AS destination_account,
        COUNT(*) AS total_incoming_transactions,
        SUM(amount) AS total_incoming_amount
    FROM paysim
    GROUP BY nameDest
),

fraud_labelled_destinations AS (
    SELECT DISTINCT nameOrig AS destination_account
    FROM paysim
    WHERE isFraud = 1
)

SELECT
    f.destination_account,
    f.suspicious_transaction_count,
    f.distinct_fraud_history_senders,
    f.suspicious_incoming_amount,
    t.total_incoming_transactions,
    t.total_incoming_amount,

    ROUND(
        100.0 * f.suspicious_transaction_count
        / NULLIF(t.total_incoming_transactions, 0),
        2
    ) AS suspicious_exposure_percentage

FROM fraud_history_exposure f
JOIN total_incoming t
    ON f.destination_account = t.destination_account

WHERE NOT EXISTS (
    SELECT 1
    FROM fraud_labelled_destinations d
    WHERE d.destination_account = f.destination_account
)

ORDER BY
    suspicious_exposure_percentage DESC,
    f.distinct_fraud_history_senders DESC;
--25. For each account, compute a running average and running max of transaction amount
--up to and including the current one (ordered by step ) — "how does this compare to what
--I've seen from this account so far," which is the shape real-time scoring actually needs.
select nameOrig,
       step,
	   amount,
	   avg(amount) over (partition by nameOrig order by step 
	                    rows between unbounded preceding and current row) as running_avg_amount,
	   max(amount) over (partition by nameOrig order by step 
	                     rows between unbounded preceding and current row) as running_max_amount
from paysim;
--26. Detect a structuring ring: 3+ distinct origin accounts all paying 
-- the same destination, each just under 200,000, within a tight step window.
SELECT
    nameDest,
    FLOOR(step / 24.0) AS step_bucket,
    COUNT(DISTINCT nameOrig) AS distinct_sender_accounts,
    COUNT(*) AS qualifying_transaction_count,
    SUM(amount) AS total_transaction_amount
FROM paysim
WHERE amount BETWEEN 150000 AND 199999
GROUP BY
    nameDest,
    FLOOR(step / 24.0)
HAVING COUNT(DISTINCT nameOrig) >= 3
ORDER BY
    distinct_sender_accounts DESC,
    qualifying_transaction_count DESC;
--27.Write a single-pass query — no correlated subquery — that returns every account's
-- transaction count, total amount, and fraud rate. It needs to hold up on 100M+ rows.
select
      nameOrig,
	  count(*) as transaction_count,
	  sum(amount) as total_amount,
	  avg(isFraud::numeric) as fraud_rate
from paysim
group by nameOrig;
--28.
























--29.Build a composite risk score per transaction from amount z-score, account velocity,
-- and destination type (merchant vs. customer), then return the top 100.
with z_score as
(
select nameOrig,
       nameDest,
	   step,
	   type,
	   amount,
	   avg(amount)over (partition by nameOrig ) as mean_amount,
	   stddev_pop(amount) over(partition by nameOrig) as sd_amount,
	   (amount - avg(amount)over (partition by nameOrig ))/nullif(stddev_pop(amount)over(partition by nameOrig),0) as zscore
from paysim
)
