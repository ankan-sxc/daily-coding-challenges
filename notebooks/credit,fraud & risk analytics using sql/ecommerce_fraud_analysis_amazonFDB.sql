--Date: 02/11/2026
--Intermediate (Q1–Q40)
--Q1. List each transaction with its merchant name and product category for orders above $500.
select transaction_id,
       merchant_name,
	   product_category,
	   purchase_value
from transactions t
join merchants m on t.merchant_id=m.merchant_id
where t.purchase_value > 500 
order by t.purchase_value desc;