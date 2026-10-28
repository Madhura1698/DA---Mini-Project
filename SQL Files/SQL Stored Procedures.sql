
USE [ABC Bank];
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- =========================================================
-- 1. usp_GetCustomerPortfolio
-- =========================================================

CREATE OR ALTER PROCEDURE dbo.usp_GetCustomerPortfolio
    @CustomerID INT
AS
BEGIN
    SET NOCOUNT ON; -- 

    ;WITH FacilitySummary AS
    (
        SELECT
            CustomerID,
            COUNT(FacilityID) AS NumberOfFacilities,
            SUM(AmountApproved) AS Total_Approved_Amount
        FROM Facilities
        WHERE Customer_Exists = 'True' -- 
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
        WHERE f.Customer_Exists = 'True' -- 
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
        WHERE f.Customer_Exists = 'True' -- 
          AND p.FacilityIDExists = 'True' -- 
          AND p.AmountMissing = 'False' -- 
        -- Negative payments are retained for net-payment analysis.
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
        ON c.CustomerID = ps.CustomerID
    WHERE c.CustomerID = @CustomerID;
END;
GO


-- =========================================================
-- 2. usp_GetDataQualitySummary
-- =========================================================

CREATE OR ALTER PROCEDURE dbo.usp_GetDataQualitySummary
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH CountInvalidFacilities AS
    (
        SELECT FacilityID
        FROM Invalid_Approvals
        WHERE Facilities_Exists = 'False'
          AND FacilityID IS NOT NULL -- 

        UNION

        SELECT FacilityID
        FROM Invalid_Collaterals
        WHERE FacilityIDExists = 'False'
          AND FacilityID IS NOT NULL -- 

        UNION

        SELECT FacilityID
        FROM Invalid_Covenant_Checks
        WHERE FacilityExistsFlag = 'False'
          AND FacilityID IS NOT NULL -- 

        UNION

        SELECT FacilityID
        FROM Invalid_Loans
        WHERE FacilitiesExistsFlag = 'False'
          AND FacilityID IS NOT NULL -- 

        UNION

        SELECT FacilityID
        FROM Invalid_Payments
        WHERE FacilityIDExists = 'False'
          AND FacilityID IS NOT NULL -- 
        -- Include invalid payment facility references.
    )

    SELECT
        CAST('InvalidFacilityReferencesCount' AS VARCHAR(50)) AS Subject,
        COUNT(*) AS [Count]
    FROM CountInvalidFacilities

    UNION ALL

    SELECT
        'DuplicateApprovalIDs',
        COUNT(CASE WHEN DuplicateApprovalID_Exists = 'True'
                   THEN 1 END)
    FROM Invalid_Approvals

    UNION ALL

    SELECT
        'DuplicateCollateralIDs',
        COUNT(CASE WHEN DuplicateExists = 'True'
                   THEN 1 END)
    FROM Invalid_Collaterals

    UNION ALL

    SELECT
        'DuplicateCovenantCheckIDs',
        COUNT(CASE WHEN DuplicateExistsFlag = 'True'
                   THEN 1 END)
    FROM Invalid_Covenant_Checks

    UNION ALL

    SELECT
        'DuplicateLoanIDs',
        COUNT(CASE WHEN DuplicatedLoanIDFlag = 'True'
                   THEN 1 END)
    FROM Invalid_Loans

    UNION ALL

    SELECT
        'FacilitiesWithInvalidCustomerRefs', -- 
        COUNT(*)
    FROM Facilities
    WHERE Customer_Exists = 'False'
    -- This counts facilities with invalid customer
    -- references, not records in the Customers table.

    UNION ALL

    SELECT
        'NegativePaymentAmounts',
        COUNT(*)
    FROM
    (
        SELECT 1 AS IssueRow
        FROM Payments
        WHERE NegativeValueExists = 'True'

        UNION ALL

        SELECT 1
        FROM Invalid_Payments
        WHERE NegativeValueExists = 'True'
    ) AS NegativePayments
    -- Check both main and invalid payment tables.

    UNION ALL

    SELECT
        'NegativeCollateralValues',
        COUNT(*)
    FROM
    (
        SELECT 1 AS IssueRow
        FROM Collaterals
        WHERE CollateralValue < 0

        UNION ALL

        SELECT 1
        FROM Invalid_Collaterals
        WHERE CollateralValue < 0
    ) AS NegativeCollaterals
    -- Check both main and invalid collateral tables.

    UNION ALL

    SELECT
        'MissingOrInvalidPaymentDates', -- 
        COUNT(*)
    FROM
    (
        SELECT 1 AS IssueRow
        FROM Payments
        WHERE PaymentDateMissingOrInvalid = 'True'

        UNION ALL

        SELECT 1
        FROM Invalid_Payments
        WHERE PaymentDateMissingOrInvalid = 'True'
    ) AS InvalidPaymentDates
    --  Use the validation flag, which also covers
    -- invalid dates, not just dates stored as NULL.

    UNION ALL

    SELECT
        'MissingPaymentAmounts',
        COUNT(*)
    FROM
    (
        SELECT 1 AS IssueRow
        FROM Payments
        WHERE AmountMissing = 'True'

        UNION ALL

        SELECT 1
        FROM Invalid_Payments
        WHERE AmountMissing = 'True'
    ) AS MissingPaymentAmounts
    --  Use the flag and include both tables.

    UNION ALL

    SELECT
        'MissingPaymentStatus',
        COUNT(*)
    FROM
    (
        SELECT 1 AS IssueRow
        FROM Payments
        WHERE StatusMissing = 'True'

        UNION ALL

        SELECT 1
        FROM Invalid_Payments
        WHERE StatusMissing = 'True'
    ) AS MissingPaymentStatus;
    --  Use the flag and include both tables.

END;
GO


-- =========================================================
-- 3. usp_GetFacilityRisk
-- =========================================================

CREATE OR ALTER PROCEDURE dbo.usp_GetFacilityRisk
    @FacilityID INT = NULL
AS
BEGIN
    SET NOCOUNT ON; -- 

    ;WITH Loan_Details AS
    (
        SELECT
            l.FacilityID,
            SUM(l.DisbursedAmount) AS DisbursedAmount,
            COUNT(CASE WHEN l.LoanStatus = 'Active'
                       THEN 1 END) AS ActiveLoanCount
        FROM Loans l
        INNER JOIN Facilities f
            ON l.FacilityID = f.FacilityID
        WHERE f.Customer_Exists = 'True' -- 
        GROUP BY l.FacilityID
    ),
    PaymentDetails AS
    (
        SELECT
            p.FacilityID,
            COUNT(CASE WHEN p.Status = 'Missed'
                       THEN 1 END) AS MissedPaymentCount,
            COUNT(CASE WHEN p.Status = 'Partial'
                       THEN 1 END) AS PartialPaymentCount
        FROM Payments p
        INNER JOIN Facilities f
            ON p.FacilityID = f.FacilityID
        WHERE p.FacilityIDExists = 'True' -- 
          AND f.Customer_Exists = 'True' -- 
          AND p.NegativeValueExists = 'False' -- 
          AND p.PaymentDateMissingOrInvalid = 'False' -- 
          AND p.AmountMissing = 'False' -- 
          AND p.StatusMissing = 'False' -- 
        -- Count only eligible payments for payment-risk metrics.
        GROUP BY p.FacilityID
    ),
    CollateralDetails AS
    (
        SELECT
            c.FacilityID,
            SUM(c.CollateralValue) AS CollateralValue,
            f.AmountApproved AS AmountApproved,

            --  Decimal arithmetic and division-by-zero safety.
            CAST(
                100.0 * SUM(c.CollateralValue)
                / NULLIF(f.AmountApproved, 0)
                AS DECIMAL(10,2)
            ) AS CollateralCoverage

        FROM Collaterals c
        INNER JOIN Facilities f
            ON c.FacilityID = f.FacilityID
        WHERE c.NegativeValueExists = 'False'
          AND c.DuplicateExists = 'False' -- 
          AND c.FacilityIDExists = 'True' -- 
          AND f.Customer_Exists = 'True' -- 
          AND f.AmountApproved > 0
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
        WHERE f.Customer_Exists = 'True' -- 
        GROUP BY cc.FacilityID
    )
    SELECT
        f.FacilityID,
        c.CustomerID,
        c.CustomerName,
        f.AmountApproved,
        ld.DisbursedAmount,
        ld.ActiveLoanCount,
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
    WHERE f.Customer_Exists = 'True' -- 
      AND (@FacilityID IS NULL OR f.FacilityID = @FacilityID);
      --  NULL returns all eligible facilities.
      -- A supplied ID returns only that eligible facility.

END;
GO
