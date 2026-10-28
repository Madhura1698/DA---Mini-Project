USE [ABC Bank]
GO
/****** Object:  View [dbo].[vw_LoanPortfolio]    Script Date: 26-10-2026 13:27:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE   VIEW [dbo].[vw_LoanPortfolio]
AS

SELECT
    l.LoanID,
    f.FacilityID,
    c.CustomerID,
    c.CustomerName,
    l.DisbursedAmount,
    l.InterestRate,
    l.LoanStatus
FROM Loans l
LEFT JOIN Facilities f
    ON l.FacilityID = f.FacilityID
LEFT JOIN Customers c
    ON f.CustomerID = c.CustomerID
WHERE f.Customer_Exists = 'True'
    -- CORRECTION 9: Exclude loans linked to facilities
    -- whose customer reference is invalid.
    -- The filter also excludes loans without a matching facility.
    AND c.CustomerID IS NOT NULL;
    -- CORRECTION 10: Require a matching customer for the valid portfolio.
GO
/****** Object:  View [dbo].[vw_PaymentPerformance]    Script Date: 26-10-2026 13:27:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE   VIEW [dbo].[vw_PaymentPerformance]
AS

SELECT
    p.PaymentID,
    p.FacilityID,
    c.CustomerID,
    c.CustomerName,
    p.PaymentDate,
    p.Amount,
    p.Status,
    p.NegativeValueExists,

    -- CORRECTION 11: Expose the payment validation flags
    -- so that later analytical queries can apply the appropriate rules.
    p.FacilityIDExists,
    p.PaymentDateMissingOrInvalid,
    p.AmountMissing,
    p.StatusMissing

FROM Payments p
LEFT JOIN Facilities f
    ON p.FacilityID = f.FacilityID
LEFT JOIN Customers c
    ON f.CustomerID = c.CustomerID
WHERE p.FacilityIDExists = 'True'
    -- CORRECTION 12: Include only payments with valid facility references.
    AND f.Customer_Exists = 'True';
    -- CORRECTION 13: Exclude payments linked to facilities
    -- whose customer reference is invalid.
    -- Negative payments are NOT filtered out here.
    -- Missing date/status flags remain visible for further analysis.
GO
/****** Object:  View [dbo].[Loan_Payment_Records]    Script Date: 26-10-2026 13:27:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[Loan_Payment_Records]
AS
SELECT
    lp.FacilityID,
    lp.CustomerID,
    lp.CustomerName,
    lp.LoanID,
    lp.LoanStatus,
    lp.DisbursedAmount,
    pp.PaymentID,
    pp.PaymentDate,
    pp.Amount AS PaymentAmount,
    pp.Status AS PaymentStatus,
    pp.NegativeValueExists
FROM dbo.vw_LoanPortfolio lp
LEFT JOIN dbo.vw_PaymentPerformance pp
    ON lp.FacilityID = pp.FacilityID;
GO
/****** Object:  View [dbo].[vw_CustomerPortfolio]    Script Date: 26-10-2026 13:27:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--Use [ABC Bank]
CREATE   VIEW [dbo].[vw_CustomerPortfolio]
AS

WITH FacilitySummary AS
(
    SELECT
        CustomerID,
        COUNT(FacilityID) AS NumberOfFacilities,
        SUM(AmountApproved) AS Total_Approved_Amount
    FROM Facilities
    WHERE Customer_Exists = 'True'
        -- CORRECTION 1: Only include facilities linked to valid customers.
    GROUP BY CustomerID
),
LoanSummary AS
(
    SELECT
        f.CustomerID,
        COUNT(l.LoanID) AS NumberOfLoans,
        COUNT(CASE WHEN l.LoanStatus = 'Active' THEN 1 END) AS ActiveLoans,
        SUM(l.DisbursedAmount) AS Total_Disbursed_Amount
    FROM Facilities f
    INNER JOIN Loans l
        ON f.FacilityID = l.FacilityID
    WHERE f.Customer_Exists = 'True'
        -- CORRECTION 2: Exclude loans associated with facilities
        -- whose customer reference is invalid.
    GROUP BY f.CustomerID
),
PaymentSummary AS
(
    SELECT
        f.CustomerID,
        SUM(p.Amount) AS TotalPayments
    FROM Facilities f
    INNER JOIN Payments p
        ON f.FacilityID = p.FacilityID
    WHERE f.Customer_Exists = 'True'
        -- CORRECTION 3: Exclude facilities linked to invalid customers.
        AND p.FacilityIDExists = 'True'
        -- CORRECTION 4: Exclude payments with invalid facility references.
        AND p.AmountMissing = 'False'
        -- CORRECTION 5: Exclude payments with missing amounts from the sum.
        -- Negative amounts are intentionally retained for net-payment analysis.
    GROUP BY f.CustomerID
)
SELECT
    c.CustomerID,
    c.CustomerName,
    fs.NumberOfFacilities,
    ls.NumberOfLoans,
    ls.ActiveLoans,
    fs.Total_Approved_Amount,
    ls.Total_Disbursed_Amount,
    ps.TotalPayments
FROM Customers c
LEFT JOIN FacilitySummary fs
    ON c.CustomerID = fs.CustomerID
LEFT JOIN LoanSummary ls
    ON c.CustomerID = ls.CustomerID
LEFT JOIN PaymentSummary ps
    ON c.CustomerID = ps.CustomerID;
GO
/****** Object:  View [dbo].[vw_FacilityPortfolio]    Script Date: 26-10-2026 13:27:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE   VIEW [dbo].[vw_FacilityPortfolio]
AS

WITH LoanDetails AS
(
    SELECT
        l.FacilityID,
        COUNT(l.LoanID) AS LoanCount,
        COUNT(CASE WHEN l.LoanStatus = 'Active' THEN 1 END) AS ActiveLoanCount,
        SUM(l.DisbursedAmount) AS DisbursedAmount
    FROM Loans l
    INNER JOIN Facilities f
        ON l.FacilityID = f.FacilityID
        -- CORRECTION 6: Link loan calculations to facilities.
    WHERE f.Customer_Exists = 'True'
        -- CORRECTION 7: Exclude loans linked to facilities
        -- whose customer reference is invalid.
    GROUP BY l.FacilityID
)

SELECT
    f.FacilityID,
    c.CustomerID,
    c.CustomerName,
    f.FacilityType,
    f.AmountApproved,
    f.StartDate,
    f.TenorMonths,
    ld.LoanCount,
    ld.ActiveLoanCount,
    ld.DisbursedAmount
FROM Facilities f
INNER JOIN Customers c
    ON f.CustomerID = c.CustomerID
LEFT JOIN LoanDetails ld
    ON f.FacilityID = ld.FacilityID
WHERE f.Customer_Exists = 'True';
    -- CORRECTION 8: Explicitly exclude facilities whose customer reference is invalid.
GO
/****** Object:  View [dbo].[vw_FacilityRisk]    Script Date: 26-10-2026 13:27:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE   VIEW [dbo].[vw_FacilityRisk]
AS

WITH Loan_Details AS
(
    SELECT
        l.FacilityID,
        SUM(l.DisbursedAmount) AS DisbursedAmount,
        COUNT(CASE WHEN l.LoanStatus = 'Active' THEN 1 END) AS ActiveLoanCount,
        SUM(CASE WHEN l.LoanStatus='Active' THEN DisbursedAmount END) AS ActiveLoanExposure
    FROM Loans l
    INNER JOIN Facilities f
        ON l.FacilityID = f.FacilityID
        -- Limit loan risk calculations to known facilities.
    WHERE f.Customer_Exists = 'True'
        -- Exclude facilities with invalid customer references.
    GROUP BY l.FacilityID
),
PaymentDetails AS
(
    SELECT
        p.FacilityID,
        COUNT(CASE WHEN p.Status = 'Missed' THEN 1 END) AS MissedPaymentCount,
        COUNT(CASE WHEN p.Status = 'Partial' THEN 1 END) AS PartialPaymentCount
    FROM Payments p
    INNER JOIN Facilities f
        ON p.FacilityID = f.FacilityID
        --  Join payments to their facilities.
    WHERE p.FacilityIDExists = 'True'
        --  Exclude invalid facility references.
        AND f.Customer_Exists = 'True'
        --  Exclude facilities linked to invalid customers.
        AND p.NegativeValueExists = 'False'
        --  Negative payments are excluded from payment-risk counts.
        AND p.PaymentDateMissingOrInvalid = 'False'
        --  Exclude payments with missing/invalid dates.
        AND p.AmountMissing = 'False'
        --  Exclude payments with missing amounts.
        AND p.StatusMissing = 'False'
        --  Exclude payments with missing statuses.
    GROUP BY p.FacilityID
),
CollateralDetails AS
(
    SELECT
        c.FacilityID,
        SUM(c.CollateralValue) AS CollateralValue,
        f.AmountApproved AS AmountApproved,

        --  Use decimal arithmetic and NULLIF
        -- to avoid integer-division issues and division by zero.
        CAST(
            SUM(c.CollateralValue) * 100.0
            / NULLIF(f.AmountApproved, 0)
            AS DECIMAL(10,2)
        ) AS CollateralCoverage

    FROM Collaterals c
    INNER JOIN Facilities f
        ON c.FacilityID = f.FacilityID
    WHERE c.NegativeValueExists = 'False'
        --  Exclude negative collateral values.
        AND f.Customer_Exists = 'True'
        --  Exclude facilities linked to invalid customers.
        AND f.AmountApproved > 0
        --  Calculate coverage only for positive approved amounts.
    GROUP BY
        c.FacilityID,
        f.AmountApproved
),
CovenantCount AS
(
    SELECT
        cc.FacilityID,
        COUNT(cc.CovenantID) AS CovenantCount
    FROM Covenant_Checks cc
    INNER JOIN Facilities f
        ON cc.FacilityID = f.FacilityID
        --  Link covenant checks to their facilities.
    WHERE f.Customer_Exists = 'True'
        --  Exclude facilities linked to invalid customers.
    GROUP BY cc.FacilityID
)
SELECT
    f.FacilityID,
    c.CustomerID,
    c.CustomerName,
    f.AmountApproved,
    ld.DisbursedAmount,
    ld.ActiveLoanCount,
    ld.ActiveLoanExposure,
    pd.MissedPaymentCount,
    pd.PartialPaymentCount,
    cd.CollateralValue,
    cd.CollateralCoverage,
    cc.CovenantCount
FROM Facilities f
INNER JOIN Customers c
    ON f.CustomerID = c.CustomerID
LEFT JOIN Loan_Details ld
    ON ld.FacilityID = f.FacilityID
LEFT JOIN PaymentDetails pd
    ON pd.FacilityID = f.FacilityID
LEFT JOIN CollateralDetails cd
    ON cd.FacilityID = f.FacilityID
LEFT JOIN CovenantCount cc
    ON cc.FacilityID = f.FacilityID
WHERE f.Customer_Exists = 'True';
    --  Return only facilities linked to valid customers.
GO
