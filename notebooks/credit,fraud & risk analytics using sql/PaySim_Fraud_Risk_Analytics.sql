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

       