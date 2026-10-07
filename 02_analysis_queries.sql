/* ============================================================
   BANKING CUSTOMER & TRANSACTION ANALYSIS USING SQL
   File: 02_analysis_queries.sql
   Purpose: 15 business-driven analytical queries covering
            JOINs, CTEs, Window Functions, Aggregations,
            CASE statements, and Date functions.
   ============================================================ */


/* ------------------------------------------------------------
   Q1. CUSTOMER 360 VIEW  (Multi-table JOIN)
   Business need: A single view combining customer profile,
   home branch, and their transaction/account details.
------------------------------------------------------------ */
SELECT
    c.Customer_ID,
    c.Age,
    c.Customer_Type,
    c.City            AS Customer_City,
    br.City           AS Branch_City,
    br.Region,
    t.Account_Type,
    t.Total_Balance,
    t.Investment_Type,
    t.Transaction_Date
FROM Customers c
JOIN Branches br      ON c.Branch_ID = br.Branch_ID
JOIN Transactions t   ON c.Customer_ID = t.Customer_ID
LIMIT 20;


/* ------------------------------------------------------------
   Q2. TOTAL BALANCE & TRANSACTION VOLUME BY CITY  (Aggregation)
   Business need: Which cities hold the most deposits?
------------------------------------------------------------ */
SELECT
    br.City,
    COUNT(DISTINCT c.Customer_ID)   AS Total_Customers,
    COUNT(t.Transaction_ID)         AS Total_Transactions,
    SUM(t.Total_Balance)            AS Total_Balance,
    ROUND(AVG(t.Total_Balance), 2)  AS Avg_Balance
FROM Branches br
JOIN Customers c     ON br.Branch_ID = c.Branch_ID
JOIN Transactions t  ON c.Customer_ID = t.Customer_ID
GROUP BY br.City
ORDER BY Total_Balance DESC;


/* ------------------------------------------------------------
   Q3. CUSTOMER SEGMENTATION BY AGE GROUP  (CASE statement)
   Business need: Group customers into age bands for targeted
   marketing campaigns.
------------------------------------------------------------ */
SELECT
    CASE
        WHEN Age < 25            THEN '18-24'
        WHEN Age BETWEEN 25 AND 35 THEN '25-35'
        WHEN Age BETWEEN 36 AND 50 THEN '36-50'
        WHEN Age BETWEEN 51 AND 65 THEN '51-65'
        WHEN Age > 65             THEN '65+'
        ELSE 'Unknown'
    END AS Age_Group,
    COUNT(*) AS Num_Customers
FROM Customers
GROUP BY Age_Group
ORDER BY Num_Customers DESC;


/* ------------------------------------------------------------
   Q4. HIGH-VALUE CUSTOMER FLAGGING  (CASE + Aggregation)
   Business need: Flag customers whose total balance across
   accounts crosses a premium threshold, for relationship
   manager prioritisation.
------------------------------------------------------------ */
SELECT
    c.Customer_ID,
    c.Customer_Type,
    SUM(t.Total_Balance) AS Combined_Balance,
    CASE
        WHEN SUM(t.Total_Balance) >= 100000 THEN 'High Value'
        WHEN SUM(t.Total_Balance) >= 50000  THEN 'Mid Value'
        ELSE 'Standard'
    END AS Customer_Segment
FROM Customers c
JOIN Transactions t ON c.Customer_ID = t.Customer_ID
GROUP BY c.Customer_ID, c.Customer_Type
ORDER BY Combined_Balance DESC
LIMIT 20;


/* ------------------------------------------------------------
   Q5. DORMANT / LOW-ENGAGEMENT ACCOUNT IDENTIFICATION  (CTE + Date functions)
   Business need: Find customers whose last transaction was
   more than 12 months before the most recent date in the data,
   i.e. likely dormant accounts.
------------------------------------------------------------ */
WITH Latest_Txn AS (
    SELECT
        Customer_ID,
        MAX(Transaction_Date) AS Last_Txn_Date
    FROM Transactions
    GROUP BY Customer_ID
),
Data_Max_Date AS (
    SELECT MAX(Transaction_Date) AS Max_Date FROM Transactions
)
SELECT
    lt.Customer_ID,
    lt.Last_Txn_Date,
    CAST(JULIANDAY(dm.Max_Date) - JULIANDAY(lt.Last_Txn_Date) AS INT) AS Days_Since_Last_Txn
FROM Latest_Txn lt
CROSS JOIN Data_Max_Date dm
WHERE JULIANDAY(dm.Max_Date) - JULIANDAY(lt.Last_Txn_Date) > 365
ORDER BY Days_Since_Last_Txn DESC
LIMIT 20;


/* ------------------------------------------------------------
   Q6. MONTHLY TRANSACTION TREND  (Date functions + Aggregation)
   Business need: Track transaction volume and value trend
   month over month (feeds a "Transactions Over Time" chart).
------------------------------------------------------------ */
SELECT
    STRFTIME('%Y-%m', Transaction_Date) AS Txn_Month,
    COUNT(*)                            AS Num_Transactions,
    SUM(Transaction_Amount)             AS Total_Txn_Amount
FROM Transactions
GROUP BY Txn_Month
ORDER BY Txn_Month;


/* ------------------------------------------------------------
   Q7. YEAR-OVER-YEAR GROWTH IN TRANSACTION VALUE  (Window function - LAG)
   Business need: Compare each year's total transaction value
   against the previous year to measure growth.
------------------------------------------------------------ */
WITH Yearly AS (
    SELECT
        STRFTIME('%Y', Transaction_Date) AS Txn_Year,
        SUM(Transaction_Amount)          AS Total_Amount
    FROM Transactions
    GROUP BY Txn_Year
)
SELECT
    Txn_Year,
    Total_Amount,
    LAG(Total_Amount) OVER (ORDER BY Txn_Year)              AS Prev_Year_Amount,
    ROUND(
        (Total_Amount - LAG(Total_Amount) OVER (ORDER BY Txn_Year)) * 100.0
        / LAG(Total_Amount) OVER (ORDER BY Txn_Year), 2
    ) AS YoY_Growth_Pct
FROM Yearly
ORDER BY Txn_Year;


/* ------------------------------------------------------------
   Q8. TOP 3 CUSTOMERS BY BALANCE WITHIN EACH CITY  (Window function - RANK)
   Business need: Identify the top relationship-value customers
   per city for regional account managers.
------------------------------------------------------------ */
WITH Ranked AS (
    SELECT
        br.City,
        c.Customer_ID,
        t.Total_Balance,
        RANK() OVER (PARTITION BY br.City ORDER BY t.Total_Balance DESC) AS City_Rank
    FROM Customers c
    JOIN Branches br     ON c.Branch_ID = br.Branch_ID
    JOIN Transactions t  ON c.Customer_ID = t.Customer_ID
)
SELECT *
FROM Ranked
WHERE City_Rank <= 3
ORDER BY City, City_Rank;


/* ------------------------------------------------------------
   Q9. RUNNING TOTAL OF DEPOSITS OVER TIME  (Window function - SUM OVER)
   Business need: Cumulative balance growth trend for the bank.
------------------------------------------------------------ */
SELECT
    Transaction_Date,
    Transaction_Amount,
    SUM(Transaction_Amount) OVER (ORDER BY Transaction_Date) AS Running_Total
FROM Transactions
ORDER BY Transaction_Date
LIMIT 50;


/* ------------------------------------------------------------
   Q10. ACCOUNT TYPE DISTRIBUTION & AVERAGE BALANCE  (Aggregation + CASE)
   Business need: Compare Savings/Current/Business accounts by
   volume and financial contribution (mirrors "Transactions by
   Type" chart).
------------------------------------------------------------ */
SELECT
    Account_Type,
    COUNT(*)                          AS Num_Accounts,
    ROUND(AVG(Total_Balance), 2)      AS Avg_Balance,
    ROUND(AVG(Transaction_Amount), 2) AS Avg_Txn_Amount,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM Transactions), 2) AS Pct_Of_Total
FROM Transactions
GROUP BY Account_Type
ORDER BY Num_Accounts DESC;


/* ------------------------------------------------------------
   Q11. INVESTMENT PREFERENCE BY CUSTOMER TYPE  (JOIN + Aggregation + CASE)
   Business need: Understand which investment products different
   customer segments prefer, for cross-sell strategy.
------------------------------------------------------------ */
SELECT
    c.Customer_Type,
    t.Investment_Type,
    COUNT(*)                            AS Num_Investments,
    SUM(t.Investment_Amount)            AS Total_Invested,
    ROUND(AVG(t.Investment_Amount), 2)  AS Avg_Investment
FROM Customers c
JOIN Transactions t ON c.Customer_ID = t.Customer_ID
WHERE c.Customer_Type IS NOT NULL
GROUP BY c.Customer_Type, t.Investment_Type
ORDER BY c.Customer_Type, Total_Invested DESC;


/* ------------------------------------------------------------
   Q12. BRANCH PROFITABILITY RANKING  (Window function + CASE)
   Business need: Rank branches by profit margin, and flag
   underperforming branches for management review.
------------------------------------------------------------ */
SELECT
    Branch_ID,
    City,
    Region,
    Firm_Revenue,
    Expenses,
    Profit_Margin,
    RANK() OVER (ORDER BY Profit_Margin DESC) AS Profitability_Rank,
    CASE
        WHEN Profit_Margin < 20 THEN 'Underperforming'
        WHEN Profit_Margin BETWEEN 20 AND 50 THEN 'Stable'
        ELSE 'High Performing'
    END AS Performance_Flag
FROM Branches
ORDER BY Profitability_Rank
LIMIT 20;


/* ------------------------------------------------------------
   Q13. TOP 5 CITIES BY TOTAL CUSTOMER BALANCE  (Aggregation + LIMIT)
   Business need: Regional resource allocation (mirrors
   "Top 5 Cities by Total Balance" chart).
------------------------------------------------------------ */
SELECT
    br.City,
    SUM(t.Total_Balance) AS Total_Balance
FROM Branches br
JOIN Customers c     ON br.Branch_ID = c.Branch_ID
JOIN Transactions t  ON c.Customer_ID = t.Customer_ID
GROUP BY br.City
ORDER BY Total_Balance DESC
LIMIT 5;


/* ------------------------------------------------------------
   Q14. CUSTOMER RETENTION COHORT BY FIRST TRANSACTION YEAR  (CTE + Date functions)
   Business need: See how many customers acquired in each year
   are still transacting in the latest year of data.
------------------------------------------------------------ */
WITH First_Txn AS (
    SELECT
        Customer_ID,
        MIN(STRFTIME('%Y', Transaction_Date)) AS Cohort_Year
    FROM Transactions
    GROUP BY Customer_ID
),
Latest_Year AS (
    SELECT MAX(STRFTIME('%Y', Transaction_Date)) AS Max_Year FROM Transactions
),
Active_In_Latest AS (
    SELECT DISTINCT Customer_ID
    FROM Transactions, Latest_Year
    WHERE STRFTIME('%Y', Transaction_Date) = Latest_Year.Max_Year
)
SELECT
    f.Cohort_Year,
    COUNT(DISTINCT f.Customer_ID)                                   AS Cohort_Size,
    COUNT(DISTINCT a.Customer_ID)                                   AS Still_Active,
    ROUND(100.0 * COUNT(DISTINCT a.Customer_ID) / COUNT(DISTINCT f.Customer_ID), 2) AS Retention_Pct
FROM First_Txn f
LEFT JOIN Active_In_Latest a ON f.Customer_ID = a.Customer_ID
GROUP BY f.Cohort_Year
ORDER BY f.Cohort_Year;


/* ------------------------------------------------------------
   Q15. BELOW-AVERAGE BALANCE CUSTOMERS PER ACCOUNT TYPE  (Subquery + Window function)
   Business need: Identify customers whose balance is below the
   average for their own account type, useful for targeted
   savings-product outreach.
------------------------------------------------------------ */
SELECT
    Transaction_ID,
    Customer_ID,
    Account_Type,
    Total_Balance,
    Avg_Balance_For_Type
FROM (
    SELECT
        Transaction_ID,
        Customer_ID,
        Account_Type,
        Total_Balance,
        AVG(Total_Balance) OVER (PARTITION BY Account_Type) AS Avg_Balance_For_Type
    FROM Transactions
) sub
WHERE Total_Balance < Avg_Balance_For_Type
ORDER BY Account_Type, Total_Balance
LIMIT 20;


/* ------------------------------------------------------------
   Q16. REGIONAL PERFORMANCE SUMMARY  (Multi-JOIN + Aggregation + CASE)
   Business need: Executive-level snapshot of business health by
   region for the quarterly review deck.
------------------------------------------------------------ */
SELECT
    br.Region,
    COUNT(DISTINCT br.Branch_ID)            AS Num_Branches,
    COUNT(DISTINCT c.Customer_ID)           AS Num_Customers,
    SUM(t.Total_Balance)                    AS Total_Deposits,
    ROUND(AVG(br.Profit_Margin), 2)         AS Avg_Branch_Profit_Margin,
    CASE
        WHEN AVG(br.Profit_Margin) >= 50 THEN 'Strong Region'
        WHEN AVG(br.Profit_Margin) >= 30 THEN 'Moderate Region'
        ELSE 'Needs Attention'
    END AS Region_Health
FROM Branches br
JOIN Customers c     ON br.Branch_ID = c.Branch_ID
JOIN Transactions t  ON c.Customer_ID = t.Customer_ID
GROUP BY br.Region
ORDER BY Total_Deposits DESC;
