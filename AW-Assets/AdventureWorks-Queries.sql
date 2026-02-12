--Data Preparation & Cleaning
/*
1) Handle NULLs in Product attributes:
Identify products where Size, Color, Style, or Class is NULL (common in Production.Product). Then create a view (v_Cleaned_Products) replacing NULLs with meaningful defaults like 'Unknown' or 'N/A' using ISNULL or COALESCE.
Use tables: Production.Product (columns: ProductID, Name, Size, Color, Style, Class).
Expected output (for view): Columns - ProductID, Name, CleanedSize, CleanedColor, CleanedStyle, CleanedClass.
*/
select
	*
from
	production.Product
where
	size is null
	or
	color is null
	or
	Style is null
	or
	class is null
;

create view vCleaned_Products as
select
	ProductID,
	Name as ProductName,
	coalesce(Size,'No Size') as CleanedSize,
	coalesce(color,'No Color') as CleanedColor,
	coalesce(Style,'No Style') as CleanedStyle,
	coalesce(Size,'No Class') as CleanedClass
from
	production.Product
;


/*
Standardize Person titles and names
Find people with inconsistent Title values (e.g., 'Mr.', 'Mr', NULL, 'Dr.') in Person.Person. Create a cleaned version (view or CTE) standardizing Title (handle NULL → 'N/A', trim spaces, capitalize properly).
Use tables: Person.Person (columns: BusinessEntityID, Title, FirstName, MiddleName, LastName).
Expected output (for view): Columns - BusinessEntityID, StandardizedTitle, FullName (concatenated properly).
*/
create view
	vwPerson
as
	select
	BusinessEntityID,
	ISNULL(Title,'N/A') as Title,
	concat_ws(' ',FirstName,MiddleName ,LastName ) as FullName
from
	Person.Person
;

/*
Fix date format inconsistencies:
Check for invalid or future OrderDate / ShipDate values in Sales.SalesOrderHeader (e.g., dates > current date or < 2000). Write a SELECT to find anomalies, then suggest an UPDATE or view that caps/floors dates or flags them.
Use tables: Sales.SalesOrderHeader (columns: SalesOrderID, OrderDate, ShipDate).
Expected output (profiling): Columns - SalesOrderID, OrderDate, ShipDate, IsInvalid (varchar: 'Future', 'TooOld', 'Valid').
*/

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

/*
4) Remove or flag duplicate email addresses:
Identify potential duplicate email addresses in Person.EmailAddress (same email for different BusinessEntityID).
Use tables: Person.EmailAddress (columns: BusinessEntityID, EmailAddress).
Expected output: Columns - EmailAddress, CountOccurrences (int), BusinessEntityIDs (comma-separated list or example).
*/
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


/*
5) Clean phone numbers format:
Standardize PhoneNumber in Person.PersonPhone (remove parentheses, dashes, spaces; ensure consistent length). Create a view with a CleanedPhone column using REPLACE, TRIM, etc.
Use tables: Person.PersonPhone (columns: BusinessEntityID, PhoneNumber).
Expected output (for view): Columns - BusinessEntityID, OriginalPhone, CleanedPhone.
*/

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

/*
6) Handle NULL freight or tax in orders:
Find orders where Freight or TaxAmt is NULL or negative (should not be). Suggest replacement with 0 or average value from similar orders.
Use tables: Sales.SalesOrderHeader (columns: SalesOrderID, Freight, TaxAmt).
Expected output (profiling): Columns - SalesOrderID, Freight, TaxAmt, IssueType (varchar).
*/

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
	TaxAmt is null)

--Found no orders where Freight or TaxAmt is NULL or negative


/*7) Check and clean product list prices vs costs:
Identify products where ListPrice < StandardCost (unrealistic) or ListPrice is NULL. Flag or suggest correction (e.g., set minimum margin).
Use tables: Production.Product (columns: ProductID, Name, StandardCost, ListPrice).
Expected output: Columns - ProductID, Name, StandardCost, ListPrice, MarginPercent (decimal), Status (varchar: 'Invalid', 'OK').
*/

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


/*
8) Detect and remove incomplete customer records:
Find customers with no associated Person or Store (orphaned records).
Use tables: Sales.Customer (columns: CustomerID, PersonID, StoreID), Person.Person, Sales.Store.
Expected output: Columns - CustomerID, HasPerson (bit), HasStore (bit), IsIncomplete (bit).
*/

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


/*
9) Create a master cleaned sales view:
Combine cleaned versions from previous tasks into one reusable view (v_Cleaned_SalesData) joining Sales.SalesOrderHeader, Sales.SalesOrderDetail, cleaned products, and customers. Apply NULL handling, date fixes, and filters (exclude invalid records).
Use multiple tables as above.
Expected output (view columns): SalesOrderID, OrderDate (cleaned), CustomerID, ProductID, CleanedProductName, LineTotal, CleanedFreight, etc.
*/

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


/*
Basic SQL Questions
These focus on basic data retrieval and simple aggregations to identify high-level problems like total sales or top performers.

1) Total Sales Revenue:
Calculate the total sales revenue across all orders.
Use tables: Sales.SalesOrderHeader (columns: SubTotal).
Expected output: One column - TotalRevenue (decimal).
*/

select
	cast(SUM(SubTotal) as decimal(11,2)) as TotalSalesRevenue
from
	Sales.SalesOrderHeader;

/*
2) Number of Unique Customers:
Count the number of unique customers who have placed orders.
Use tables: Sales.Customer (columns: CustomerID), Sales.SalesOrderHeader (columns: CustomerID).
Expected output: One column - UniqueCustomers (int).
*/

select
	COUNT(DISTINCT SC.CustomerID) as UniqueCustomers
from
	Sales.Customer sc
join
	Sales.SalesOrderHeader soh
	on
	sc.CustomerID = soh.CustomerID;

/*
3) Top 5 Products by Quantity Sold:
List the top 5 products by total quantity sold.
Use tables: Production.Product (columns: ProductID, Name), Sales.SalesOrderDetail (columns: ProductID, OrderQty).
Expected output: Columns - ProductName (varchar), TotalQuantity (int).
*/

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

/*
4) Average Order Value:
Compute the average value of sales orders.
Use tables: Sales.SalesOrderHeader (columns: SubTotal).
Expected output: One column - AverageOrderValue (decimal).
*/

select
	AVG(SubTotal) as AverageOrderValue
from
	Sales.SalesOrderHeader
;

/*
5) Sales by Year: Aggregate total sales revenue by year.
Use tables: Sales.SalesOrderHeader (columns: OrderDate, SubTotal).
Expected output: Columns - Year (int), TotalRevenue (decimal).
*/

select
	YEAR(OrderDate) as OrderYear,
	cast(SUM(SubTotal) as decimal(10,2)) as TotalRevenue
from
	Sales.SalesOrderHeader
group by
	YEAR(OrderDate)
order by
	OrderYear
;

/*
6) Number of Orders per Territory:
Count the number of orders per sales territory.
Use tables: Sales.SalesTerritory (columns: TerritoryID, Name), Sales.SalesOrderHeader (columns: TerritoryID).
Expected output: Columns - TerritoryName (varchar), OrderCount (int).
*/

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

/*
7) Total Freight Costs:
Calculate the total freight costs incurred.
Use tables: Sales.SalesOrderHeader (columns: Freight).
Expected output: One column - TotalFreight (decimal).
*/

select
	cast(SUM(Freight) as decimal(10,2)) as TotalFreight
from
	Sales.SalesOrderHeader;


/*
8) Products with No Sales:
List products that have never been sold.
Use tables: Production.Product (columns: ProductID, Name), Sales.SalesOrderDetail (columns: ProductID).
Expected output: Columns - ProductID (int), ProductName (varchar).
*/

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


/*
9) Customer Count by Store:
Count customers associated with each store (for reseller channel).
Use tables: Sales.Store (columns: BusinessEntityID, Name), Sales.Customer (columns: StoreID).
Expected output: Columns - StoreName (varchar), CustomerCount (int).
*/

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


/*
10) Total Sales Tax Collected:
Sum the total sales tax amount from all orders.
Use tables: Sales.SalesOrderHeader (columns: TaxAmt).
Expected output: One column - TotalTax (decimal).
*/

select
	cast(SUM(TaxAmt) as decimal(10,2)) as TotalTax
from
	Sales.SalesOrderHeader;



/*
Intermediate SQL Questions

These involve joins and groupings to find reasons behind problems, such as correlations between products, customers, and sales.

1) Sales by Product Category:
Aggregate sales revenue by product category.
Use tables: Production.Product (columns: ProductID), Production.ProductSubcategory (columns: ProductSubcategoryID, Name), Production.ProductCategory (columns: ProductCategoryID, Name), Sales.SalesOrderDetail (columns: ProductID, LineTotal).
Expected output: Columns - CategoryName (varchar), TotalRevenue (decimal).
*/

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


/*
2) Top Customers by Revenue:
Identify the top 10 customers by total revenue, including their names.
Use tables: Person.Person (columns: BusinessEntityID, FirstName, LastName), Sales.Customer (columns: CustomerID, PersonID), Sales.SalesOrderHeader (columns: CustomerID, SubTotal).
Expected output: Columns - CustomerName (varchar), TotalRevenue (decimal).
*/

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


/*
3) Sales Performance by Salesperson:
Calculate total sales revenue per salesperson.
Use tables: Sales.SalesPerson (columns: BusinessEntityID), Person.Person (columns: BusinessEntityID, FirstName, LastName), Sales.SalesOrderHeader (columns: SalesPersonID, SubTotal).\
Expected output: Columns - SalespersonName (varchar), TotalRevenue (decimal).,
*/

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


/*
4) Orders with Discounts:
List orders where a discount was applied, including discount amount.
Use tables: Sales.SalesOrderHeader (columns: SalesOrderID), Sales.SalesOrderDetail (columns: SalesOrderID, UnitPriceDiscount, LineTotal).
Expected output: Columns - SalesOrderID (int), TotalDiscount (decimal).
*/

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

/*
5) Product Cost vs. Selling Price:
Compare standard cost and list price for products sold.
Use tables: Production.Product (columns: ProductID, Name, StandardCost, ListPrice), Sales.SalesOrderDetail (columns: ProductID).
Expected output: Columns - ProductName (varchar), StandardCost (decimal), ListPrice (decimal), Margin (decimal).
*/

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


/*
6) Sales by Region and Month:
Aggregate sales by territory and month.
Use tables: Sales.SalesTerritory (columns: TerritoryID, Name), Sales.SalesOrderHeader (columns: TerritoryID, OrderDate, SubTotal).
Expected output: Columns - TerritoryName (varchar), MonthYear (varchar), TotalRevenue (decimal).
*/
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


/*
7) Days to Ship Orders:
Find the number of days taken to ship orders from the date of purchase.
Use tables: Sales.SalesOrderHeader (columns: SalesOrderID, OrderDate, ShipDate).
Expected output: Columns - SalesOrderID (int), OrderDate (date), DaysTakenToShip (int).
*/

select
	SalesOrderID,
	convert(varchar(15),OrderDate,6) as OrderDate,
	DATEDIFF(day,OrderDate,ShipDate) as DaysTakenToShip
from
	Sales.SalesOrderHeader
order by
	OrderDate
;


/*
8) Customer Churn Indicator:
Identify customers who haven't ordered in the last year (assume current date as max OrderDate).
Use tables: Sales.Customer (columns: CustomerID), Sales.SalesOrderHeader (columns: CustomerID, OrderDate).
Expected output: Columns - CustomerID (int), LastOrderDate (date).
*/

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


/*
9) Vendor Performance:
Calculate average purchase order total per vendor.
Use tables: Purchasing.Vendor (columns: BusinessEntityID, Name), Purchasing.PurchaseOrderHeader (columns: VendorID, SubTotal).
Expected output: Columns - VendorName (varchar), AverageOrderValue (decimal).
*/

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


/*
10) Products with High Inventory:
List products with inventory quantity above 1000.
Use tables: Production.Product (columns: ProductID, Name), Production.ProductInventory (columns: ProductID, Quantity).
Expected output: Columns - ProductName (varchar), TotalInventory (int).
*/

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



/*
Advanced SQL Questions

These use complex techniques like CTEs, window functions, and rankings to provide deep insights and suggestions, such as forecasting trends or optimizing strategies.

1) Year-over-Year Sales Growth:
Calculate year-over-year growth percentage for total sales.
Use tables: Sales.SalesOrderHeader (columns: OrderDate, SubTotal).
Expected output: Columns - Year (int), TotalRevenue (decimal), GrowthPercentage (decimal).
*/

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


/*
2) Customer Lifetime Value (CLV):
Estimate CLV as total revenue per customer divided by number of years active.
Use tables: Sales.Customer (columns: CustomerID), Sales.SalesOrderHeader (columns: CustomerID, OrderDate, SubTotal).
Expected output: Columns - CustomerID (int), CLV (decimal).
*/

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


/*
3) Product Ranking by Revenue Contribution:
Rank products by their contribution to total revenue using window functions.
Use tables: Production.Product (columns: ProductID, Name), Sales.SalesOrderDetail (columns: ProductID, LineTotal).
Expected output: Columns - ProductName (varchar), Revenue (decimal), RevenueRank (int).
*/

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


/*
4) Seasonal Sales Trends:
Identify peak sales months using CTEs and aggregations.
Use tables: Sales.SalesOrderHeader (columns: OrderDate, SubTotal).
Expected output: Columns - Month (int), AverageRevenue (decimal), Trend (varchar, e.g., 'Peak' if above average).
*/

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
	2 desc;


/*
5) Cohort Analysis for Customer Retention:
Group customers by first order year and calculate retention rate over subsequent years.
Use tables: Sales.SalesOrderHeader (columns: CustomerID, OrderDate).
Expected output: Columns - CohortYear (int), YearAfter (int), RetentionRate (decimal).
*/

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

/*
6) Profit Margin by Territory:
Calculate profit margin (revenue - cost) per territory, ranking them.
Use tables: Sales.SalesTerritory (columns: TerritoryID, Name), Sales.SalesOrderHeader (columns: TerritoryID, SubTotal), Sales.SalesOrderDetail (columns: SalesOrderID, ProductID, OrderQty), Production.Product (columns: ProductID, StandardCost).
Expected output: Columns - TerritoryName (varchar), ProfitMargin (decimal), Rank (int).
*/

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


/*
7) Anomaly Detection in Orders:
Find orders where subtotal deviates more than 2 standard deviations from average.
Use tables: Sales.SalesOrderHeader (columns: SalesOrderID, SubTotal).
Expected output: Columns - SalesOrderID (int), SubTotal (decimal), Deviation (decimal).
*/

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


/*
8) Supply Chain Delays:
Analyze average time from purchase order to receipt for vendors, using window functions for ranking.
Use tables: Purchasing.PurchaseOrderHeader (columns: PurchaseOrderID, VendorID, OrderDate), Purchasing.PurchaseOrderDetail (columns: PurchaseOrderID, ReceivedQty, DueDate).
Expected output: Columns - VendorID (int), AvgDelayDays (decimal), DelayRank (int).
*/

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


/*
9) Forecasting Inventory Needs:
Predict next month's inventory needs based on last 3 months' sales velocity (using CTEs).
Use tables: Sales.SalesOrderDetail (columns: ProductID, OrderQty, modifieddate as proxy for date), Production.ProductInventory (columns: ProductID, Quantity).
Expected output: Columns - ProductID (int), ProjectedSales (int), CurrentInventory (int), ReorderSuggestion (varchar).
*/

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


/*
10) Segmented Customer Analysis:
Segment customers into 'High', 'Medium', 'Low' value based on RFM (Recency, Frequency, Monetary) scores using CTEs and NTILE.
Use tables: Sales.SalesOrderHeader (columns: CustomerID, OrderDate, SubTotal).
Expected output: Columns - CustomerID (int), RFM_Score (int), Segment (varchar).
*/

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
order by
	CustomerID;