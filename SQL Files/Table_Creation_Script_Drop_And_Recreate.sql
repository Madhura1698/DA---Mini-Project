/*
   ABC Bank - Table Creation Script (Drop and Recreate)
   Purpose: Recreate the project tables with the schema defined below, then add foreign keys.

   WARNING: This script DROPS and RECREATES all 12 project tables. ALL DATA in these tables will be lost.
   Run only when a fresh/empty setup is intended, or after backing up any data you need to keep.

   Notes:
   - Invalid tables intentionally have no primary key on source/business IDs so duplicate records can be retained.
   - Invalid_Facilities is intentionally omitted per the project design.
   - SSIS handles Facilities rows with Customer_Exists = False by checking the validation flag before loading.
*/
USE [ABC Bank];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- 0. Drop existing tables in dependency-safe order.
-- Invalid destination tables have no foreign keys; drop them before the main tables.
DROP TABLE IF EXISTS [dbo].[Invalid_Covenant_Checks];
DROP TABLE IF EXISTS [dbo].[Invalid_Collaterals];
DROP TABLE IF EXISTS [dbo].[Invalid_Approvals];
DROP TABLE IF EXISTS [dbo].[Invalid_Payments];
DROP TABLE IF EXISTS [dbo].[Invalid_Loans];
GO

-- Drop child tables before dbo.Facilities because they reference FacilityID.
DROP TABLE IF EXISTS [dbo].[Covenant_Checks];
DROP TABLE IF EXISTS [dbo].[Collaterals];
DROP TABLE IF EXISTS [dbo].[Approvals];
DROP TABLE IF EXISTS [dbo].[Payments];
DROP TABLE IF EXISTS [dbo].[Loans];
GO

-- Drop master tables last.
DROP TABLE IF EXISTS [dbo].[Facilities];
DROP TABLE IF EXISTS [dbo].[Customers];
GO

-- 1. Master tables (create referenced tables first)
-- Table: dbo.Customers
    CREATE TABLE [dbo].[Customers](
    	[CustomerID] [int] NOT NULL,
    	[CustomerName] [nvarchar](100) NULL,
    	[IncorporationDate] [date] NULL,
    	[Employees] [decimal](10, 2) NULL,
    	[CreditScore] [decimal](5, 2) NULL,
    PRIMARY KEY CLUSTERED 
    (
    	[CustomerID] ASC
    )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
    ) ON [PRIMARY];
GO

-- Table: dbo.Facilities
    CREATE TABLE [dbo].[Facilities](
    	[FacilityID] [int] NOT NULL,
    	[CustomerID] [int] NOT NULL,
    	[FacilityType] [nvarchar](50) NULL,
    	[AmountApproved] [decimal](30, 10) NULL,
    	[StartDate] [date] NULL,
    	[TenorMonths] [decimal](10, 2) NULL,
    	[Customer_Exists] [nvarchar](20) NULL,
    PRIMARY KEY CLUSTERED 
    (
    	[FacilityID] ASC
    )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
    ) ON [PRIMARY];
GO

-- Table: dbo.Loans
    CREATE TABLE [dbo].[Loans](
    	[LoanID] [int] NOT NULL,
    	[FacilityID] [int] NOT NULL,
    	[DisbursedAmount] [decimal](30, 10) NULL,
    	[InterestRate] [decimal](30, 10) NULL,
    	[LoanStatus] [nvarchar](50) NULL,
    	[DuplicatedLoanIDFlag] [nvarchar](20) NULL,
    	[FacilitiesExistsFlag] [nvarchar](20) NULL,
    PRIMARY KEY CLUSTERED 
    (
    	[LoanID] ASC
    )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
    ) ON [PRIMARY];
GO

-- Table: dbo.Payments
    CREATE TABLE [dbo].[Payments](
    	[PaymentID] [int] NOT NULL,
    	[FacilityID] [int] NOT NULL,
    	[PaymentDate] [date] NULL,
    	[Amount] [decimal](30, 10) NULL,
    	[Status] [nvarchar](20) NULL,
    	[NegativeValueExists] [nvarchar](50) NULL,
    	[FacilityIDExists] [nvarchar](50) NULL,
    	[PaymentDateMissingOrInvalid] [nvarchar](50) NULL,
    	[AmountMissing] [nvarchar](50) NULL,
    	[StatusMissing] [nvarchar](50) NULL,
    PRIMARY KEY CLUSTERED 
    (
    	[PaymentID] ASC
    )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
    ) ON [PRIMARY];
GO

-- Table: dbo.Approvals
    CREATE TABLE [dbo].[Approvals](
    	[ApprovalID] [int] NOT NULL,
    	[FacilityID] [int] NOT NULL,
    	[ApprovalDate] [date] NULL,
    	[ApprovedBy] [nvarchar](50) NULL,
    	[ApprovalStatus] [nvarchar](50) NULL,
    	[Facilities_Exists] [nvarchar](50) NULL,
    	[DuplicateApprovalID_Exists] [nvarchar](50) NULL,
    PRIMARY KEY CLUSTERED 
    (
    	[ApprovalID] ASC
    )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
    ) ON [PRIMARY];
GO

-- Table: dbo.Collaterals
    CREATE TABLE [dbo].[Collaterals](
    	[CollateralID] [int] NOT NULL,
    	[FacilityID] [int] NOT NULL,
    	[CollateralType] [nvarchar](50) NULL,
    	[CollateralValue] [decimal](30, 10) NULL,
    	[DuplicateExists] [nvarchar](50) NULL,
    	[NegativeValueExists] [nvarchar](50) NULL,
    	[FacilityIDExists] [nvarchar](50) NULL,
    PRIMARY KEY CLUSTERED 
    (
    	[CollateralID] ASC
    )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
    ) ON [PRIMARY];
GO

-- Table: dbo.Covenant_Checks
    CREATE TABLE [dbo].[Covenant_Checks](
    	[CovenantID] [int] NOT NULL,
    	[FacilityID] [int] NOT NULL,
    	[CovenantType] [nvarchar](50) NULL,
    	[Threshold] [decimal](30, 10) NULL,
    	[LastCheckedDate] [date] NULL,
    	[DuplicateExistsFlag] [nvarchar](20) NULL,
    	[FacilityExistsFlag] [nvarchar](20) NULL,
    PRIMARY KEY CLUSTERED 
    (
    	[CovenantID] ASC
    )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
    ) ON [PRIMARY];
GO

-- 2. Invalid-record destination tables
-- Table: dbo.Invalid_Loans
    CREATE TABLE [dbo].[Invalid_Loans](
    	[LoanID] [int] NULL,
    	[FacilityID] [int] NULL,
    	[DisbursedAmount] [decimal](30, 10) NULL,
    	[InterestRate] [decimal](30, 10) NULL,
    	[LoanStatus] [nvarchar](50) NULL,
    	[DuplicatedLoanIDFlag] [nvarchar](20) NULL,
    	[FacilitiesExistsFlag] [nvarchar](20) NULL
    ) ON [PRIMARY];
GO

-- Table: dbo.Invalid_Payments
    CREATE TABLE [dbo].[Invalid_Payments](
    	[PaymentID] [int] NULL,
    	[FacilityID] [int] NULL,
    	[PaymentDate] [date] NULL,
    	[Amount] [decimal](30, 10) NULL,
    	[Status] [nvarchar](20) NULL,
    	[NegativeValueExists] [nvarchar](50) NULL,
    	[FacilityIDExists] [nvarchar](50) NULL,
    	[PaymentDateMissingOrInvalid] [nvarchar](50) NULL,
    	[AmountMissing] [nvarchar](50) NULL,
    	[StatusMissing] [nvarchar](50) NULL
    ) ON [PRIMARY];
GO

-- Table: dbo.Invalid_Approvals
    CREATE TABLE [dbo].[Invalid_Approvals](
    	[ApprovalID] [int] NULL,
    	[FacilityID] [int] NULL,
    	[ApprovalDate] [date] NULL,
    	[ApprovedBy] [nvarchar](50) NULL,
    	[ApprovalStatus] [nvarchar](50) NULL,
    	[Facilities_Exists] [nvarchar](50) NULL,
    	[DuplicateApprovalID_Exists] [nvarchar](50) NULL
    ) ON [PRIMARY];
GO

-- Table: dbo.Invalid_Collaterals
    CREATE TABLE [dbo].[Invalid_Collaterals](
    	[CollateralID] [int] NULL,
    	[FacilityID] [int] NULL,
    	[CollateralType] [nvarchar](50) NULL,
    	[CollateralValue] [decimal](30, 10) NULL,
    	[DuplicateExists] [nvarchar](50) NULL,
    	[NegativeValueExists] [nvarchar](50) NULL,
    	[FacilityIDExists] [nvarchar](50) NULL
    ) ON [PRIMARY];
GO

-- Table: dbo.Invalid_Covenant_Checks
    CREATE TABLE [dbo].[Invalid_Covenant_Checks](
    	[CovenantID] [int] NULL,
    	[FacilityID] [int] NULL,
    	[CovenantType] [nvarchar](50) NULL,
    	[Threshold] [decimal](30, 10) NULL,
    	[LastCheckedDate] [date] NULL,
    	[DuplicateExistsFlag] [nvarchar](20) NULL,
    	[FacilityExistsFlag] [nvarchar](20) NULL
    ) ON [PRIMARY];
GO

-- 3. Foreign-key constraints (added after all tables exist)
ALTER TABLE [dbo].[Facilities] WITH CHECK ADD CONSTRAINT [FK_Facilities_Customers] FOREIGN KEY ([CustomerID]) REFERENCES [dbo].[Customers] ([CustomerID]);
GO

ALTER TABLE [dbo].[Loans] WITH CHECK ADD CONSTRAINT [FK_Loans_Facilities] FOREIGN KEY ([FacilityID]) REFERENCES [dbo].[Facilities] ([FacilityID]);
GO

ALTER TABLE [dbo].[Payments] WITH CHECK ADD CONSTRAINT [FK_Payments_Facilities] FOREIGN KEY ([FacilityID]) REFERENCES [dbo].[Facilities] ([FacilityID]);
GO

ALTER TABLE [dbo].[Approvals] WITH CHECK ADD CONSTRAINT [FK_Approvals_Facilities] FOREIGN KEY ([FacilityID]) REFERENCES [dbo].[Facilities] ([FacilityID]);
GO

ALTER TABLE [dbo].[Collaterals] WITH CHECK ADD CONSTRAINT [FK_Collaterals_Facilities] FOREIGN KEY ([FacilityID]) REFERENCES [dbo].[Facilities] ([FacilityID]);
GO

ALTER TABLE [dbo].[Covenant_Checks] WITH CHECK ADD CONSTRAINT [FK_Covenant_Facilities] FOREIGN KEY ([FacilityID]) REFERENCES [dbo].[Facilities] ([FacilityID]);
GO
