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