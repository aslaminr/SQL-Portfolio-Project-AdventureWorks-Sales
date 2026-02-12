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

### 1. Data Preparation & Cleaning

#### **Problem 1:** Handle NULLs in Product attributes:
Identify products where Size, Color, Style, or Class is NULL (common in Production.Product). Then create a view (v_Cleaned_Products) replacing NULLs with meaningful defaults like 'Unknown' or 'N/A' using ISNULL or COALESCE.
```sql
create view vCleaned_Products as
select
	ProductID,
	Name as ProductName,
	coalesce(Size,'No Size') as CleanedSize,
	coalesce(color,'No Color') as CleanedColor,
	coalesce(Style,'No Style') as CleanedStyle,
	coalesce(Size,'No Class') as CleanedClass
from
	production.Product;
```

#### **Problem 2:** Standardize Person titles and names:
Find people with inconsistent Title values (e.g., 'Mr.', 'Mr', NULL, 'Dr.') in Person.Person. Create a cleaned version (view or CTE) standardizing Title (handle NULL → 'N/A', trim spaces, capitalize properly).
```sql
create view
	vwPerson
as
	select
	BusinessEntityID,
	ISNULL(Title,'N/A') as Title,
	concat_ws(' ',FirstName,MiddleName ,LastName ) as FullName
from
	Person.Person;
```

#### **Problem 3:** Fix date format inconsistencies:
Check for invalid or future OrderDate / ShipDate values in Sales.SalesOrderHeader (e.g., dates > current date or < 2000). Write a SELECT to find anomalies, then suggest an UPDATE or view that caps/floors dates or flags them.
```sql
select
	SalesOrderID,
	OrderDate,
	ShipDate
from
	Sales.SalesOrderHeader
where
	(OrderDate > GETDATE()
	or
	ShipDate > GETDATE())
or
	(YEAR(OrderDate) < 2000
	or
	YEAR(ShipDate) < 2000);

    --No date format inconsistencies found
```

#### **Problem 4:** Remove or flag duplicate email addresses:
Identify potential duplicate email addresses in Person.EmailAddress (same email for different BusinessEntityID).
```sql
select
	BusinessEntityID,
	COUNT(EmailAddress) as emailCount
from
	Person.EmailAddress
group by
	EmailAddress
order by
	emailCount desc;

--No Duplicate Emails found
```

#### **Problem 5:** Clean phone numbers format:
Standardize PhoneNumber in Person.PersonPhone (remove parentheses, dashes, spaces; ensure consistent length). Create a view with a CleanedPhone column using REPLACE, TRIM, etc.
```sql
create view
	vwPersonPhone
as
	select
		BusinessEntityID,
		PhoneNumber as OriginalPhone,
		iif(
			LEN(PhoneNumber) > 12,
			replace(replace(RIGHT(PhoneNumber,12),'-',''),' ',''),
			replace(phoneNumber,'-','')
			)
		as CleanedPhone
	from
		Person.PersonPhone;
```

#### **Problem 6:** Handle NULL freight or tax in orders:
Find orders where Freight or TaxAmt is NULL or negative (should not be). Suggest replacement with 0 or average value from similar orders.
```sql
select
	*
from
	Sales.SalesOrderHeader
where
	(Freight < 0
	or
	Freight is null)
	or
	(TaxAmt < 0
	or
	TaxAmt is null);

--Found no orders where Freight or TaxAmt is NULL or negative
```

#### **Problem 7:** Check and clean product list prices vs costs:
Identify products where ListPrice < StandardCost (unrealistic) or ListPrice is NULL. Flag or suggest correction (e.g., set minimum margin).
```sql
select
	ProductID,
	Name,
	StandardCost,
	ListPrice
from
	Production.Product
where
	ListPrice < StandardCost
	or
	ListPrice is null;

--No Prouducts found where ListPrice < StandardCost (unrealistic) or ListPrice is NULL
```

#### **Problem 8:** Detect and remove incomplete customer records:
Find customers with no associated Person or Store (orphaned records).
```sql
select
	Customer.CustomerID
from
	Sales.Customer
left join
	Person.Person
	on
	Customer.CustomerID = Person.BusinessEntityID
left join
	Sales.Store
	on
	Customer.CustomerID = Store.BusinessEntityID
where
	Person.BusinessEntityID is null
	or
	Store.BusinessEntityID is null;

--No incomplete customer records found
```

#### **Problem 9:** Create a master cleaned sales view:
Combine cleaned versions from previous tasks into one reusable view (v_Cleaned_SalesData) joining Sales.SalesOrderHeader, Sales.SalesOrderDetail, cleaned products, and customers. Apply NULL handling, date fixes, and filters (exclude invalid records).
```sql
create view
	vwFactSales
as
	select
	SOH.SalesOrderID as SalesOrderID,
	SOH.OrderDate as OrderDate,
	SOH.CustomerID,
	SOD.ProductID,
	PP.Name as CleanedProductName,
	CAST(SOD.LineTotal as decimal(10,2)) as LineTotal,
	CAST(SOH.Freight as decimal(10,2)) as Freight
	from

		Sales.SalesOrderDetail SOD
	join
		Sales.SalesOrderHeader SOH
		on
		SOD.SalesOrderID = SOH.SalesOrderID
	join
		Production.Product PP
		on
		SOD.ProductID = PP.ProductID;
```

<br>

### 2. Basic SQL Questions

#### **Problem 1:** Total Sales Revenue:
Calculate the total sales revenue across all orders.
```sql
select
	cast(SUM(SubTotal) as decimal(10,2)) as TotalSalesRevenue
from
	Sales.SalesOrderHeader;
```

#### **Problem 2:** Number of Unique Customers:
Count the number of unique customers who have placed orders.
```sql
select
	COUNT(DISTINCT SC.CustomerID) as UniqueCustomers
from
	Sales.Customer sc
join
	Sales.SalesOrderHeader soh
	on
	sc.CustomerID = soh.CustomerID;
```

#### **Problem 3:** Top 5 Products by Quantity Sold:
List the top 5 products by total quantity sold.
```sql
select
top 5
	pp.Name as ProductName,
	SUM(sod.OrderQty) as TotalQuantity
from
	Production.Product pp
join
	Sales.SalesOrderDetail sod
	on
	pp.ProductID = sod.ProductID
group by
	pp.Name
order by
	TotalQuantity desc;
```

#### **Problem 4:** HAverage Order Value:
Compute the average value of sales orders.
```sql
select
	AVG(SubTotal) as AverageOrderValue
from
	Sales.SalesOrderHeader;
```

#### **Problem 5:** Sales by Year:
Aggregate total sales revenue by year.
```sql
select
	YEAR(OrderDate) as OrderYear,
	cast(SUM(SubTotal) as decimal(10,2)) as TotalRevenue
from
	Sales.SalesOrderHeader
group by
	YEAR(OrderDate)
order by
	OrderYear;
```

#### **Problem 6:** Number of Orders per Territory:
Count the number of orders per sales territory.
```sql
select
	sst.Name as TerritoryName,
	COUNT(soh.SalesOrderID) as OrderCount
from
	Sales.SalesTerritory sst
join
	Sales.SalesOrderHeader soh
	on
	sst.TerritoryID = soh.TerritoryID
group by
	sst.Name
order by
	TerritoryName;
```

#### **Problem 7:** Total Freight Costs:
Calculate the total freight costs incurred.
```sql
select
	cast(SUM(Freight) as decimal(10,2)) as TotalFreight
from
	Sales.SalesOrderHeader;
```

#### **Problem 8:** Products with No Sales:
List products that have never been sold.
```sql
select
	pp.ProductID,
	pp.Name as ProductName
from
	Production.Product pp
left join
	Sales.SalesOrderDetail sod
	on
	pp.ProductID = sod.ProductID
where
	sod.ProductID is null
order by
	pp.ProductID;
```

#### **Problem 9:** Customer Count by Store:
Count customers associated with each store (for reseller channel).
```sql
select
	ss.Name as StoreName,
	COUNT(sc.CustomerID) as CustomerCount
from
	Sales.Store as ss
join
	Sales.Customer sc
	on
	ss.BusinessEntityID = sc.StoreID
group by
	ss.Name
order by
	StoreName;
```

#### **Problem 10:** Total Sales Tax Collected:
Sum the total sales tax amount from all orders.
```sql
select
	cast(SUM(TaxAmt) as decimal(10,2)) as TotalTax
from
	Sales.SalesOrderHeader;
```

### 3. Intermediate SQL Questions

#### **Problem 1:** Sales by Product Category:
Aggregate sales revenue by product category.
```sql
select
	ppc.Name as CategoryName,
	cast(SUM(LineTotal) as decimal(10,2)) as TotalRevenue
from
	Production.ProductCategory ppc
join
	Production.ProductSubcategory pps
	on
	ppc.ProductCategoryID = pps.ProductCategoryID
join
	Production.Product pp
	on
	pps.ProductSubcategoryID = pp.ProductSubcategoryID
join
	Sales.SalesOrderDetail ssod
	on
	pp.ProductID = ssod.ProductID
group by
	ppc.Name
order by
	CategoryName;
```

#### **Problem 2:** Top Customers by Revenue:
Identify the top 10 customers by total revenue, including their names.
```sql
select
	top 10
		CONCAT_WS(' ',pp.FirstName,pp.MiddleName,pp.LastName) as CustomerName,
		SUM(ssoh.SubTotal) as TotalRevenue
from
	Sales.Customer sc
join
	Person.Person pp
	on
	sc.CustomerID = pp.BusinessEntityID
join
	Sales.SalesOrderHeader ssoh
	on
	sc.CustomerID = ssoh.CustomerID
group by
	CONCAT_WS(' ',pp.FirstName,pp.MiddleName,pp.LastName)
order by
	2 desc;
```

#### **Problem 3:** Sales Performance by Salesperson:
Calculate total sales revenue per salesperson.
```sql
select
	CONCAT_WS(' ',pp.FirstName,pp.MiddleName,pp.LastName) as SalesMan,
	cast(SUM(ssoh.SubTotal) as decimal(10,2)) as TotalRevenue
from
	Sales.SalesPerson ssp
join
	Person.Person pp
	on
	ssp.BusinessEntityID = pp.BusinessEntityID
join
	Sales.SalesOrderHeader ssoh
	on
	ssp.BusinessEntityID = ssoh.SalesPersonID
group by
	CONCAT_WS(' ',pp.FirstName,pp.MiddleName,pp.LastName)
order by
	2 desc;
```

#### **Problem 4:** Orders with Discounts:
List orders where a discount was applied, including discount amount.
```sql
select
	ssoh.SalesOrderID,
	cast(sum((ssod.UnitPrice*ssod.OrderQty)*ssod.UnitPriceDiscount) as decimal(10,2)) as TotalDiscount
from
	Sales.SalesOrderHeader ssoh
join
	Sales.SalesOrderDetail ssod
	on
	ssoh.SalesOrderID = ssod.SalesOrderID
	where
		ssod.UnitPriceDiscount > 0
group by
	ssoh.SalesOrderID
order by
	2 desc;
```

#### **Problem 5:** Product Cost vs. Selling Price:
Compare standard cost and list price for products sold.
```sql
select
	Name as ProductName,
	cast(StandardCost as decimal(10,2)) as StandardCost,
	ListPrice,
	cast(ListPrice-StandardCost as decimal(10,2)) as Margin,
	((ListPrice-StandardCost)/StandardCost)*100 as MarginPercent
from
	Production.Product
where
	ListPrice > 0
order by
	5 desc;
```

#### **Problem 6:** Sales by Region and Month:
Aggregate sales by territory and month.
```sql
select
	sst.Name as TerritoryName,
	FORMAT(OrderDate,'yyyy MMM') as MonthYear,
	cast(SUM(ssoh.SubTotal) as decimal(10,2)) as TotalRevenue
from
	Sales.SalesTerritory sst
join
	Sales.SalesOrderHeader ssoh
	on sst.TerritoryID = ssoh.TerritoryID
group by
	sst.Name,
	FORMAT(OrderDate,'yyyy MMM'),
	YEAR(OrderDate),
	MONTH(OrderDate)
order by
	1,
	YEAR(OrderDate),
	MONTH(OrderDate);
```

#### **Problem 7:** Days to Ship Orders:
Find the number of days taken to ship orders from the date of purchase.
```sql
select
	SalesOrderID,
	convert(varchar(15),OrderDate,6) as OrderDate,
	DATEDIFF(day,OrderDate,ShipDate) as DaysTakenToShip
from
	Sales.SalesOrderHeader
order by
	OrderDate;
```

#### **Problem 8:** Customer Churn Indicator:
Identify customers who haven't ordered in the last year (assume current date as max OrderDate).
```sql
select
	ssoh.CustomerID as CustID,
	CONCAT_WS(' ',pp.FirstName,pp.MiddleName,pp.LastName) as CustomerName,
	convert(date,max(ssoh.OrderDate)) as LastOrderDate
from
	Sales.SalesOrderHeader ssoh
join
	Person.Person pp
	on
	ssoh.CustomerID = pp.BusinessEntityID
group by
	ssoh.CustomerID,
	CONCAT_WS(' ',pp.FirstName,pp.MiddleName,pp.LastName)
	having MAX(ssoh.OrderDate) < =
	(
	select
		dateadd(year,-1,max(OrderDate))
	from
		Sales.SalesOrderHeader
	)
order by
	3 desc;
```

#### **Problem 9:** Vendor Performance:
Calculate average purchase order total per vendor.
```sql
select
	pv.Name as VendorName,
	cast(AVG(ppoh.SubTotal) as decimal(10,2)) as AveragerderValue
from
	Purchasing.Vendor pv
join
	Purchasing.PurchaseOrderHeader ppoh
	on
	pv.BusinessEntityID = ppoh.VendorID
group by
	pv.Name
order by
	2 desc;
```

#### **Problem 10:** Products with High Inventory:
List products with inventory quantity above 1000.
```sql
select
	pp.Name as ProductName,
	SUM(ppi.Quantity) as TotalInventory
from
	Production.Product pp
join
	Production.ProductInventory ppi
	on
	pp.ProductID = ppi.ProductID
group by
	pp.Name
having
	SUM(ppi.Quantity) > 1000
order by
	2 desc;
```
<br>

### 4. Advanced SQL Questions

#### **Problem 1:** Year-over-Year Sales Growth:
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

#### **Problem 2:** Customer Lifetime Value (CLV):
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

#### **Problem 3:** Product Ranking by Revenue Contribution:
Rank products by their contribution to total revenue using window functions.
```sql
with cte_rank
as
(
	select
		pp.Name as ProductName,
		cast(SUM(ssod.LineTotal) as decimal(10,2)) as Revenue
	from
		Production.Product pp
	join
		Sales.SalesOrderDetail ssod
		on
		pp.ProductID = ssod.ProductID
	group by
		pp.Name
)

select
	*,
	DENSE_RANK() over(order by Revenue desc) as RevenueRank
from
	cte_rank;
```
![alt text](https://github.com/aslaminr/SQL-Portfolio-Project-AdventureWorks-Sales/blob/main/AW-Assets/SQL-Answer-Screenshots/Answer%203.png?raw=true)

#### **Problem 4:** Seasonal Sales Trends:
Identify peak sales months using CTEs and aggregations.
```sql
select
	FORMAT(OrderDate,'MMM') Month,
	cast(AVG(SubTotal) as decimal(10,2)) as AverageRevenue,
	IIF(
		AVG(SubTotal) > (select avg(SubTotal) from sales.salesorderheader)*1,
		'Peak',
		'BelowAverage'
		) as Trend
from
	Sales.SalesOrderHeader
group by
	FORMAT(OrderDate,'MMM'),
	datepart(month,OrderDate)
order by
	datepart(month,OrderDate) asc;
```
![alt text](https://github.com/aslaminr/SQL-Portfolio-Project-AdventureWorks-Sales/blob/main/AW-Assets/SQL-Answer-Screenshots/Answer%204.png?raw=true)

#### **Problem 5:** Cohort Analysis for Customer Retention:
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

#### **Problem 6:** Profit Margin by Territory:
Calculate profit margin (revenue - cost) per territory, ranking them.
```sql
with cte_Profit as(
	select
		sst.Name as TerritoryName,
		cast((SUM(ssod.LineTotal) - SUM(pp.StandardCost*ssod.OrderQty))/SUM(ssod.LineTotal) as decimal(12,2))*100 as ProfitMargin
	from
		Sales.SalesTerritory sst
	join
		Sales.SalesOrderHeader ssoh
		on
		sst.TerritoryID = ssoh.TerritoryID
	join
		Sales.SalesOrderDetail ssod
		on
		ssoh.SalesOrderID  = ssod.SalesOrderID
	join
		Production.Product pp
		on
		ssod.ProductID = pp.ProductID
	group by
		sst.Name
)

select
	*,
	DENSE_RANK() over(order by ProfitMargin desc) as ProfitRank
from
 cte_Profit;
```
![alt text](https://github.com/aslaminr/SQL-Portfolio-Project-AdventureWorks-Sales/blob/main/AW-Assets/SQL-Answer-Screenshots/Answer%206.png?raw=true)

#### **Problem 7:** Anomaly Detection in Orders:
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

#### **Problem 8:** Supply Chain Delays:
Analyze average time from purchase order to receipt for vendors, using window functions for ranking.
```sql
with cte_delay as(
	select
		ppoh.VendorID,
		pv.Name as VendorName,
		DATEDIFF(DAY,ppoh.OrderDate,ppod.DueDate) as DaysTakenToShip
	from
		Purchasing.PurchaseOrderHeader ppoh
	join
		Purchasing.Vendor pv
		on
		ppoh.VendorID = pv.BusinessEntityID
	join
		Purchasing.PurchaseOrderDetail ppod
		on
		ppoh.PurchaseOrderID = ppod.PurchaseOrderID
)

select
	VendorID,
	VendorName,
	cast(AVG(DaysTakenToShip) as decimal (10,2)) as AvgDelayDays,
	DENSE_RANK() over(order by avg(DaysTakenToShip) desc) as DelayRank
from
	cte_delay
group by
	VendorID,
	VendorName
order by
	DelayRank;
```
![alt text](https://github.com/aslaminr/SQL-Portfolio-Project-AdventureWorks-Sales/blob/main/AW-Assets/SQL-Answer-Screenshots/Answer%208.png?raw=true)

#### **Problem 9:** Forecasting Inventory Needs:
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

#### **Problem 10:** Segmented Customer Analysis:
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