# AdventureWorks Sales & Business Performance Analysis

![Project Banner](https://github.com/aslaminr/SQL-Portfolio-Project-AdventureWorks-Sales/blob/main/AW-Assets/Banner/Adventure%20Works%20Minimal%20Banner%202.jpg?raw=true)  

## 📌 Project Overview

**End-to-end SQL-based business analysis** using the Microsoft **AdventureWorks OLTP** sample database.  
The project demonstrates real-world data analyst skills: data cleaning, exploratory analysis, advanced analytics (cohorts, RFM, forecasting, anomaly detection), and actionable business recommendations.

**Database**: [AdventureWorks OLTP (SQL Server) – 2019 version](https://learn.microsoft.com/en-us/sql/samples/adventureworks-install-configure?view=sql-server-ver16)  
**Tools used**: SQL Server Management Studio (SSMS), T-SQL  
**Focus areas**: Sales performance, customer behavior, profitability, inventory, supply chain

## 🎯 Problem Statement / Business Objective

Adventure Works Cycles is facing inconsistent sales performance and profitability across regions, products, customer segments, and time periods.  
The company wants to understand:

- Which territories, products, and customer groups are underperforming or overperforming?
- What are the root causes of sales/profit fluctuations?
- How can we improve customer retention, inventory planning, and supply chain efficiency?
- Which actionable steps should sales, marketing, operations, and finance teams take?

This project uses SQL to answer these questions with data-driven insights.

## 🗃️ Database Schema & ER Diagram

AdventureWorks is a comprehensive OLTP schema with ~70 tables across multiple schemas (Sales, Production, Purchasing, Person, HumanResources, etc.).

### Key Tables Used
- Sales.SalesOrderHeader, Sales.SalesOrderDetail  
- Production.Product, Production.ProductInventory  
- Sales.Customer, Sales.SalesTerritory  
- Purchasing.PurchaseOrderHeader, Purchasing.PurchaseOrderDetail  
- Person.Person, etc.

### Entity-Relationship Diagram (ERD)

[AdventureWorks ER Diagram](https://github.com/aslaminr/SQL-Portfolio-Project-AdventureWorks-Sales/blob/6ad192402b50f7333ca26e89e4580b896ada1f8f/AW-Assets/AdventureWorks-ER-Diagram%20v2.pdf)  


## 🔍 SQL Analysis – Questions & Solutions

All queries are organized into four difficulty levels.

### 1. Data Preparation & Cleaning (9 tasks)
- Handling NULLs, standardizing formats, removing/fixing orphans, etc. 

### 2. Basic SQL Questions (10 queries)
- These focus on basic data retrieval and simple aggregations to identify high-level problems like total sales or top performers.

### 3. Intermediate SQL Questions (10 queries)
- Involves multi table joins and groupings to find reasons behind problems, such as correlations between products, customers, and sales.

### 4. Advanced SQL Questions (10 queries)
- Uses complex techniques like CTEs, window functions, and rankings to provide deep insights and suggestions, such as forecasting trends or optimizing strategies.

**Full SQL script**: [AnalysisQueries.sql](https://github.com/aslaminr/SQL-Portfolio-Project-AdventureWorks-Sales/blob/d4fef1effcd5a06795c5d75d556f5bc29bb5b097/AW-Assets/AdventureWorks-Queries.sql)  
  
### Sample - Advanced SQL Questions & Answers

#### Year-over-Year Sales Growth:
Calculate year-over-year growth percentage for total sales.
```sql
with cte_yoy as
(
	select
		YEAR(OrderDate) OrderYear,
		cast(SUM(SubTotal) as decimal(10,2)) TotalRevenue
	from
		Sales.SalesOrderHeader
	group by
		YEAR(OrderDate)
),

cte_yoy2 as
(
	select
		*,
		NULLIF(LAG(TotalRevenue,1) over(order by OrderYear),0) as LastYearRevenue
	from
	cte_yoy
)

select
	*,
	cast(((TotalRevenue-LastYearRevenue)/LastYearRevenue)*100 as decimal(10,2)) as GrowthPercent
from
	cte_yoy2;
```
![Output](https://github.com/aslaminr/SQL-Portfolio-Project-AdventureWorks-Sales/blob/main/AW-Assets/SQL-Answer-Screenshots/Answer%201.png?raw=true)

#### Customer Lifetime Value (CLV):
Estimate CLV as total revenue per customer divided by number of years active.
```sql
select
	ssoh.CustomerID,
	CONCAT_WS(' ',pp.FirstName,pp.MiddleName,pp.LastName) as CustomerName,
	CAST(SUM(ssoh.SubTotal)/
	nullif(COUNT(distinct YEAR(orderdate)),0) as decimal(10,2)) as CLV
from
	Sales.Customer sc
join
	sales.SalesOrderHeader ssoh
	on
	sc.CustomerID = ssoh.CustomerID
left join
	Person.Person pp
	on
	sc.PersonID = pp.BusinessEntityID
group by
	ssoh.CustomerID,
	CONCAT_WS(' ',pp.FirstName,pp.MiddleName,pp.LastName)
order by
	3 desc;
```
![alt text](https://github.com/aslaminr/SQL-Portfolio-Project-AdventureWorks-Sales/blob/main/AW-Assets/SQL-Answer-Screenshots/Answer%202.png?raw=true)

#### Cohort Analysis for Customer Retention:
Group customers by first order year and calculate retention rate over subsequent years.
```sql
-- Step 1: Find each customer's first order year (cohort)
with FirstOrder as(
	select
	CustomerID,
	MIN(year(orderDate)) as CohortYear
	from
		Sales.SalesOrderHeader
	group by
		CustomerID
),

-- Step 2: For each customer, find all years they were active (had orders)
ActiveYears as(
	select distinct
		h.CustomerID,
		YEAR(h.OrderDate) as ActiveYear
	from
		Sales.SalesOrderHeader h
),

-- Step 3: Join to get cohort + active years, calculate offset
CohortRetention as(
select
	f.CohortYear,
	a.ActiveYear - f.CohortYear as YearAfter,
	COUNT(distinct a.CustomerID) as ActiveCustomers
from
	FirstOrder f
inner join
	ActiveYears a
	on
	f.CustomerID = a.CustomerID
group by
	f.CohortYear,
	a.ActiveYear - f.CohortYear
),

-- Step 4: Get the initial size of each cohort (YearAfter = 0)
CohortSize as(
select
	CohortYear,
	ActiveCustomers as CohortSize
from
	CohortRetention
where
	YearAfter = 0
)

-- Step 5: Final result - retention rate per cohort and year after
select
	cr.CohortYear,
	cr.YearAfter,
	cast(cast(cr.ActiveCustomers as decimal(10,4)) / cs.CohortSize as decimal(10,4)) as RetentionRate
from
	CohortRetention cr
inner join
	CohortSize cs
	on
	cr.CohortYear = cs.CohortYear
order by
	cr.CohortYear,
	cr.YearAfter;
```
![alt text](https://github.com/aslaminr/SQL-Portfolio-Project-AdventureWorks-Sales/blob/main/AW-Assets/SQL-Answer-Screenshots/Answer%205.png?raw=true)

#### Anomaly Detection in Orders:
Find orders where subtotal deviates more than 2 standard deviations from average.
```sql
with cte_Stats as(
	select
		cast(AVG(SubTotal) as decimal(10,2)) as Mean,
		cast(STDEV(SubTotal) as decimal(10,2)) as SDSubTotal
	from
		Sales.SalesOrderHeader
)

select
	h.SalesOrderID,
	cast(h.SubTotal as decimal(10,2)) as SubTotal,
	cast((h.SubTotal - s.Mean) / nullif(s.SDSubTotal,0) as decimal(10,2)) as Deviation
from
	Sales.SalesOrderHeader h
cross join
	cte_Stats s
where
	ABS((h.SubTotal - s.Mean) / nullif(s.SDSubTotal,0)) > 2
order by
	Deviation desc;
```
![alt text](https://github.com/aslaminr/SQL-Portfolio-Project-AdventureWorks-Sales/blob/main/AW-Assets/SQL-Answer-Screenshots/Answer%207.png?raw=true)

#### Forecasting Inventory Needs:
Predict next month's inventory needs based on last 3 months' sales velocity (using CTEs).
```sql
WITH RecentSales AS (
    -- Get total quantity sold per product per month in the last 3 months
    SELECT 
        ssod.ProductID,
        YEAR(ssoh.OrderDate) AS SalesYear,
        MONTH(ssoh.OrderDate) AS SalesMonth,
        SUM(ssod.OrderQty) AS MonthlyQty
    FROM Sales.SalesOrderDetail ssod
    INNER JOIN Sales.SalesOrderHeader ssoh 
        ON ssod.SalesOrderID = ssoh.SalesOrderID
    WHERE ssoh.OrderDate >= DATEADD(MONTH, -3, 
            (SELECT MAX(OrderDate) FROM Sales.SalesOrderHeader))
      AND ssoh.OrderDate < DATEADD(MONTH, 0, 
            (SELECT MAX(OrderDate) FROM Sales.SalesOrderHeader))  -- up to but not including current incomplete month
    GROUP BY 
        ssod.ProductID,
        YEAR(ssoh.OrderDate),
        MONTH(ssoh.OrderDate)
),

MonthlyAverage AS (
    -- Average monthly sales quantity over the last 3 months (or fewer if data is short)
    SELECT 
        ProductID,
        AVG(MonthlyQty) AS ProjectedSalesNextMonth,
        COUNT(*) AS MonthsWithSales
    FROM RecentSales
    GROUP BY ProductID
),

CurrentStock AS (
    -- Current inventory (sum across all locations if multiple)
    SELECT 
        ProductID,
        SUM(Quantity) AS CurrentInventory
    FROM Production.ProductInventory
    GROUP BY ProductID
)

-- Final result
SELECT 
    ma.ProductID,
    CAST(ROUND(ma.ProjectedSalesNextMonth, 0) AS INT) AS ProjectedSales,
    ISNULL(cs.CurrentInventory, 0) AS CurrentInventory,
    CASE 
        WHEN ma.ProjectedSalesNextMonth > ISNULL(cs.CurrentInventory, 0) * 1.2 
            THEN 'Reorder - Urgent'
        WHEN ma.ProjectedSalesNextMonth > ISNULL(cs.CurrentInventory, 0) 
            THEN 'Reorder'
        WHEN ma.ProjectedSalesNextMonth <= ISNULL(cs.CurrentInventory, 0) * 0.5 
            THEN 'Overstock'
        ELSE 'Sufficient'
    END AS ReorderSuggestion
FROM MonthlyAverage ma
LEFT JOIN CurrentStock cs 
    ON ma.ProductID = cs.ProductID
WHERE ma.MonthsWithSales >= 1   -- only products with at least some recent sales
ORDER BY 
    ProjectedSales DESC, 
    ProductID;
```
![alt text](https://github.com/aslaminr/SQL-Portfolio-Project-AdventureWorks-Sales/blob/main/AW-Assets/SQL-Answer-Screenshots/Answer%209.png?raw=true)

#### Segmented Customer Analysis:
Segment customers into 'High', 'Medium', 'Low' value based on RFM (Recency, Frequency, Monetary) scores using CTEs and NTILE.
```sql
with cte_RFM as(
	select
		CustomerID,
		DATEDIFF(DAY,max(OrderDate),(select max(OrderDate) from Sales.SalesOrderHeader)) as R,
		COUNT(SalesOrderID) as F,
		cast(SUM(SubTotal) as decimal(10,2)) as M
	from
		Sales.SalesOrderHeader
	group by 
		CustomerID
),

cte_RFM2 as(
	select
		*,
		NTILE(5) over(order by R desc) as RScore,
		NTILE(5) over(order by F) as FScore,
		NTILE(5) over(order by M) as MScore
	from
	cte_RFM
),

cte_RFM3 as(
	select
		CustomerID,
		cast(CONCAT(RScore,FScore,MScore) as int) as RFM_Score
	from
		cte_RFM2
),

cte_RFM4 as(
	select
		CustomerID,
		RFM_Score,
		NTILE(3) over(order by RFM_Score desc) as RFM_Rank
	from
		cte_RFM3
)

select
	CustomerID,
	RFM_Score,
	case
	when RFM_Rank = 1
	then 'High Value Customer'
	when RFM_Rank = 2
	then 'Medium Value Customer'
	when RFM_Rank = 3
	then 'Low Value Customer'
	end as Segment
from
cte_RFM4
```
![alt text](https://github.com/aslaminr/SQL-Portfolio-Project-AdventureWorks-Sales/blob/main/AW-Assets/SQL-Answer-Screenshots/Answer%2010.png?raw=true)
<br>

## 📊 Key Findings & Analysis

Here are the most important business insights derived from the analysis:

### Sales Performance
- Total revenue across the dataset: **$109846381.40**  
- Sales peaked in **2014-Mar** reaching **$7217531.09** (↑ **34.5%** from previous peak)  
- Lowest performing year: **2014** with only **$20057928.81** (↓ **-54.02%** YoY)  
- Top 5 products by revenue contribution: **Mountain-200 Black, 38**, **Mountain-200 Black, 42**, **Mountain-200 Silver, 38**, **Mountain-200 Silver, 42** and **Mountain-200 Silver, 46** accounting for **17.27%** of total sales

### Profitability by Territory
- Highest profit margin territory: **Australia** – **32.00%**  
- Lowest profit margin territory: **Northeast** – **-4.00%** (potential cost or pricing issue)  
- Territories with margin < **30%** contributed **90.29** of total revenue despite **78.25%** of orders

### Customer Behavior & Retention
- **33.3%** of customers are in the **High Value** RFM segment but drive **71.25%** of total revenue  
- Year-1 retention rate dropped from **100%** in 2011 cohort to **50.14%** in 2013 cohort  
- Average churn after first year: **68.48%** of customers do not return

### Inventory & Supply Chain
- **45** products have projected next-month sales **> current inventory** → urgent reorder list recommended  
- **118** products show **> 200%** overstock relative to projected demand  
- Average vendor lead time (order to due date): **16** days  
- Worst-performing vendor (highest delay): **G & K Bicycle Corp.** – average **131** days late

### Outliers & Anomalies
- **1324** orders deviate **> 2 standard deviations** from mean order value  
- Largest outlier: Order **51131** with value **$163930.39** (deviation **14.46** σ)

## 🎯 Conclusion & Recommendations

### For Sales & Marketing Team
- Prioritize **High Value RFM customers** (loyal/high-value) with personalized offers, early access, loyalty rewards  
- Launch **win-back campaign** targeting **Low Value** customers (especially those with recency > 180–300 days)  
- Focus promotional budget on **<HighMarginProducts>** and territories with margin > **35%**

### For Operations & Inventory Planning
- Generate **weekly reorder alerts** for products where projected sales > **120%** of current stock  
- Review **overstocked items** (inventory > 300% of projected need) for clearance or return-to-vendor  
- Negotiate better lead times with **G & K Bicycle Corp.** (currently averaging **131** days)

### For Finance & Pricing Team
- Investigate **low-margin territories** (< **30%**) → possible pricing strategy, freight cost, or discount abuse  
- Monitor **high-value outlier orders** (> 2–3σ) for potential fraud, special deals, or data quality issues

### Overall Business Impact
Improving **customer retention by 10–15%** in Year-2 cohorts and **reducing stockouts/overstock** by better forecasting could increase profitability by **30%** based on current trends.
<br><br>

---

Made with ❤️ by Aslam  
[LinkedIn](https://linkedin.com/in/aslam6366)
<br>

Copyright © Aslam PP | 2026. All rights reserved.

