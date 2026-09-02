--Day 2:
----Level-1:Beginner
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
--7.