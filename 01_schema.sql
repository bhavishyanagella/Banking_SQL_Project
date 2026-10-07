/* ============================================================
   BANKING CUSTOMER & TRANSACTION ANALYSIS USING SQL
   File: 01_schema.sql
   Purpose: Create the relational schema for the banking database
   Engine tested on: SQLite (also valid, with minor tweaks, on
                      MySQL / PostgreSQL)
   ============================================================ */

DROP TABLE IF EXISTS Transactions;
DROP TABLE IF EXISTS Customers;
DROP TABLE IF EXISTS Branches;

-- ---------------------------------------------------------
-- 1. BRANCHES  (one row per bank branch)
-- ---------------------------------------------------------
CREATE TABLE Branches (
    Branch_ID       INTEGER PRIMARY KEY,
    City            TEXT NOT NULL,
    Region          TEXT NOT NULL,
    Firm_Revenue    REAL,               -- some branches have missing revenue
    Expenses        REAL NOT NULL,
    Profit_Margin   REAL NOT NULL       -- percentage
);

-- ---------------------------------------------------------
-- 2. CUSTOMERS  (one row per customer, linked to home branch)
-- ---------------------------------------------------------
CREATE TABLE Customers (
    Customer_ID     INTEGER PRIMARY KEY,
    Age             REAL,               -- some missing ages
    Customer_Type   TEXT,               -- Employee / Business / Individual (some missing)
    City            TEXT,               -- some missing
    Region          TEXT NOT NULL,
    Bank_Name       TEXT NOT NULL,
    Branch_ID       INTEGER NOT NULL,
    FOREIGN KEY (Branch_ID) REFERENCES Branches(Branch_ID)
);

-- ---------------------------------------------------------
-- 3. TRANSACTIONS  (one row per customer transaction/account snapshot)
-- ---------------------------------------------------------
CREATE TABLE Transactions (
    Transaction_ID      INTEGER PRIMARY KEY,
    Customer_ID         INTEGER NOT NULL,
    Account_Type        TEXT NOT NULL,   -- Savings / Current / Business
    Total_Balance        REAL NOT NULL,
    Transaction_Amount  REAL NOT NULL,
    Investment_Amount   REAL NOT NULL,
    Investment_Type     TEXT NOT NULL,   -- Fixed Deposit / Recurring Deposit / Mutual Fund
    Transaction_Date    TEXT NOT NULL,   -- ISO format YYYY-MM-DD
    FOREIGN KEY (Customer_ID) REFERENCES Customers(Customer_ID)
);

-- ---------------------------------------------------------
-- Helpful indexes for join / filter heavy analytical queries
-- ---------------------------------------------------------
CREATE INDEX idx_customers_branch   ON Customers(Branch_ID);
CREATE INDEX idx_customers_city     ON Customers(City);
CREATE INDEX idx_txn_customer       ON Transactions(Customer_ID);
CREATE INDEX idx_txn_date           ON Transactions(Transaction_Date);
CREATE INDEX idx_branches_city      ON Branches(City);
