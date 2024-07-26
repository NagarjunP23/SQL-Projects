--------------------   Codebasics Resume Challenge #4   -------------------

-----     Provide Insights to Management in Consumer Goods Domain     -----

---------------- Tables -------------------
select * from dim_product;
select * from fact_gross_price;
select * from fact_manufacturing_cost;
select * from fact_pre_invoice_deductions;
select * from fact_sales_monthly;
select * from dim_customer;
-------------------------------------------

/*

1. Provide the list of markets in which customer "Atliq Exclusive" operates its business
in the APAC region.

*/


SELECT DISTINCT
	market
FROM 
	dim_customer
WHERE
	customer = 'Atliq Exclusive' and region = 'APAC'
ORDER BY 1;


/*

2. What is the percentage of unique product increase in 2021 vs. 2020? 
The final output contains these fields, 
unique_products_2020 
unique_products_2021 
percentage_chg

*/

WITH CTE AS (
	SELECT count(DISTINCT product_code) as unique_products_2020 
	FROM fact_sales_monthly
	WHERE fiscal_year = 2020
),
CTE1 AS (
	SELECT count(DISTINCT product_code) as unique_products_2021
	FROM fact_sales_monthly
	WHERE fiscal_year = 2021
)
SELECT 
	unique_products_2020,
	unique_products_2021,
	ROUND((unique_products_2021-unique_products_2020)*100/unique_products_2020,2) AS percentage_chg
FROM CTE,CTE1;


/*

3. Provide a report with all the unique product counts for each segment 
and sort them in descending order of product counts. 
The final output contains 2 fields, 
segment 
product_count

*/

SELECT 
	segment, COUNT(product_code) AS product_count
FROM 
	dim_product
GROUP BY 
	segment
ORDER BY 
	product_count DESC;

/*

4. Follow-up: Which segment had the most increase in unique products in 2021 vs 2020? 
The final output contains these fields, 
segment 
product_count_2020 
product_count_2021 
difference

*/

WITH CTE AS (
	SELECT 
		segment,fiscal_year, COUNT(DISTINCT D.product_code) AS product_count_2020
	FROM 
		dim_product D
	INNER JOIN 
		fact_sales_monthly FSM
	ON 
		D.product_code = FSM.product_code
	WHERE 
		fiscal_year = 2020
	GROUP BY 
		segment,fiscal_year
),
CTE1 AS (
	SELECT 
		segment,fiscal_year, COUNT(DISTINCT D.product_code) AS product_count_2021
	FROM 
		dim_product D
	INNER JOIN 
		fact_sales_monthly FSM
	ON 
		D.product_code = FSM.product_code
	WHERE 
		fiscal_year = 2021
	GROUP BY 
		segment,fiscal_year
)
SELECT 
	CTE.segment,
	product_count_2020,
	product_count_2021,
	(product_count_2021 - product_count_2020) AS difference
FROM
	CTE,CTE1
WHERE 
	CTE.segment = CTE1.segment;

/*

5. Get the products that have the highest and lowest manufacturing costs. 
The final output should contain these fields, 
product_code 
product 
manufacturing_cost

*/


SELECT 
	FMC.product_code,
	product,
	manufacturing_cost
FROM 
	dim_product D
INNER JOIN 
	fact_manufacturing_cost FMC
ON 
	D.product_code = FMC.product_code
WHERE 
	manufacturing_cost IN (
		SELECT MAX(manufacturing_cost) FROM fact_manufacturing_cost
		UNION
		SELECT MIN(manufacturing_cost) FROM fact_manufacturing_cost
);


/*

6. Generate a report which contains the top 5 customers who received an average high
pre_invoice_discount_pct for the fiscal year 2021 and in the Indian market. 
The final output contains these fields, 
customer_code 
customer 
average_discount_percentage

*/

SELECT TOP 5
	DC.customer_code,
	customer,
	avg(pre_invoice_discount_pct) as average_discount_percentage
FROM
	fact_pre_invoice_deductions FPD
INNER JOIN 
	dim_customer DC
ON 
	FPD.customer_code = DC.customer_code
WHERE 
	fiscal_year = 2021 and market = 'India'
GROUP BY 
	DC.customer_code,customer
ORDER BY 
	average_discount_percentage DESC;



/*

7. Get the complete report of the Gross sales amount for the customer “Atliq Exclusive” for each month . 
This analysis helps to get an idea of low and high-performing months and take strategic decisions. 
The final report contains these columns: 
Month 
Year 
Gross sales Amount

*/
SELECT
	MONTH(FSM.date) AS mnth,
	FSM.fiscal_year,
	SUM(FSM.sold_quantity * FGP.gross_price ) AS Gross_sales_Amount
FROM
	fact_sales_monthly FSM
INNER JOIN 
	dim_customer DC
ON 
	FSM.customer_code = DC.customer_code
INNER JOIN 
	fact_gross_price FGP
ON 
	FSM.product_code = FGP.product_code
WHERE 
	DC.customer = 'Atliq Exclusive'
GROUP BY MONTH(FSM.date),FSM.fiscal_year
ORDER BY FSM.fiscal_year,MNTH;


/*

8. In which quarter of 2020, got the maximum total_sold_quantity? 
The final output contains these fields sorted by the total_sold_quantity, 
Quarter 
total_sold_quantity

*/

WITH CTE AS (
	SELECT 
	CASE
		WHEN date BETWEEN '2019-09-01' AND '2019-11-01' then 1  
		WHEN date BETWEEN '2019-12-01' AND '2020-02-01' then 2
		WHEN date BETWEEN '2020-03-01' AND '2020-05-01' then 3
		WHEN date BETWEEN '2020-06-01' AND '2020-08-01' then 4
		END AS Quarters,
		sold_quantity
	FROM fact_sales_monthly
	WHERE fiscal_year = 2020
	)
SELECT 
	Quarters,
	SUM(sold_quantity) AS total_sold_quantity
FROM CTE
GROUP BY Quarters
ORDER BY total_sold_quantity DESC


/*

9. Which channel helped to bring more gross sales in the fiscal year 2021 and the percentage of contribution? 
The final output contains these fields, 
channel 
gross_sales_mln 
percentage

*/

WITH CTE AS
(
SELECT C.channe,
       ROUND(SUM(G.gross_price*FS.sold_quantity/1000000), 2) AS Gross_sales_mln
FROM 
	fact_sales_monthly FS 
INNER JOIN 
	dim_customer C ON FS.customer_code = C.customer_code
INNER JOIN 
	fact_gross_price G ON FS.product_code = G.product_code
WHERE FS.fiscal_year = 2021
GROUP BY channe
),
CTE1 AS (SELECT SUM(Gross_sales_mln) AS total FROM CTE)
SELECT channe, CONCAT(Gross_sales_mln,' M') AS Gross_sales_mln , CONCAT(ROUND(Gross_sales_mln*100/total , 2), ' %') AS percentage
FROM CTE,CTE1
ORDER BY percentage DESC 


/*

10. Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021? 
The final output contains these fields, 
division 
product_code 
product 
total_sold_quantity 
rank_order

*/

WITH CTE AS (
SELECT 
	DP.division,
	DP.product_code,
	DP.product,
	SUM(FSM.sold_quantity) AS total_sold_quantity,
	RANK() OVER(PARTITION BY DP.division ORDER BY SUM(FSM.sold_quantity) DESC) AS rank_order
FROM 
	dim_product DP
INNER JOIN
	fact_sales_monthly FSM
ON DP.product_code = FSM.product_code
WHERE
	FSM.fiscal_year = 2021
GROUP BY
	DP.division,
	DP.product_code,
	DP.product
)
SELECT * FROM CTE
WHERE rank_order <= 3;



















