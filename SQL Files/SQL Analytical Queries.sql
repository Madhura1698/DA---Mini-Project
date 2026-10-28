USE [ABC Bank];
GO

-- =========================================================
-- 1. Customer Portfolio
-- =========================================================

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


-- =========================================================
-- 2. Customers with highest facility exposure
-- =========================================================

SELECT
    c.CustomerID,
    c.CustomerName,
    COUNT(f.FacilityID) AS NumberOfFacilities, -- 
    SUM(f.AmountApproved) AS Total_Approved_Amount
FROM Customers c
INNER JOIN Facilities f
    ON c.CustomerID = f.CustomerID
WHERE f.Customer_Exists = 'True' -- 
GROUP BY
    c.CustomerID,
    c.CustomerName
ORDER BY Total_Approved_Amount DESC;
GO


-- =========================================================
-- 3. Customers with active loans
-- =========================================================

SELECT
    c.CustomerID,
    c.CustomerName,
    COUNT(CASE WHEN l.LoanStatus = 'Active' THEN 1 END) AS ActiveLoans,
    SUM(CASE WHEN l.LoanStatus = 'Active'
             THEN l.DisbursedAmount ELSE 0 END) AS ActiveLoanAmount
FROM Customers c
INNER JOIN Facilities f
    ON c.CustomerID = f.CustomerID
LEFT JOIN Loans l
    ON l.FacilityID = f.FacilityID
WHERE f.Customer_Exists = 'True' -- 
GROUP BY
    c.CustomerID,
    c.CustomerName;
GO


-- =========================================================
-- 4. Facility portfolio by type
-- =========================================================

SELECT
    FacilityType,
    COUNT(FacilityID) AS FacilityCount,
    SUM(AmountApproved) AS Total_Amount_Approved,
    AVG(AmountApproved) AS Average_Amount_Approved
FROM Facilities
WHERE Customer_Exists = 'True' -- 
GROUP BY FacilityType;
GO


-- =========================================================
-- 5. Facility tenor analysis
-- =========================================================

SELECT
    TenorMonths,
    COUNT(FacilityID) AS FacilityCount,
    AVG(AmountApproved) AS Average_Amount_Approved
FROM Facilities
WHERE Customer_Exists = 'True' -- 
GROUP BY TenorMonths;
GO


-- =========================================================
-- 6. Facilities by customer
-- =========================================================

SELECT
    c.CustomerID,
    c.CustomerName,
    COUNT(f.FacilityID) AS NumberOfFacilities
FROM Customers c
INNER JOIN Facilities f
    ON c.CustomerID = f.CustomerID
WHERE f.Customer_Exists = 'True' -- 
GROUP BY
    c.CustomerID,
    c.CustomerName;
GO


-- =========================================================
-- 7. Loan status summary
-- =========================================================

SELECT
    l.LoanStatus,
    COUNT(l.LoanID) AS LoanCount,
    SUM(l.DisbursedAmount) AS TotalDisbursedAmount,
    AVG(l.InterestRate) AS Average_Interest_Rate
FROM Loans l
INNER JOIN Facilities f
    ON l.FacilityID = f.FacilityID -- 
WHERE f.Customer_Exists = 'True' -- 
GROUP BY l.LoanStatus;
GO


-- =========================================================
-- 8. Active loan exposure
-- =========================================================

SELECT
    c.CustomerID,
    c.CustomerName,
    COUNT(l.LoanID) AS ActiveLoanCount,
    SUM(l.DisbursedAmount) AS ActiveDisbursedAmount,
    AVG(l.InterestRate) AS AverageInterestRate
FROM Customers c
INNER JOIN Facilities f
    ON c.CustomerID = f.CustomerID
INNER JOIN Loans l -- 
    ON f.FacilityID = l.FacilityID
WHERE l.LoanStatus = 'Active'
  AND f.Customer_Exists = 'True' -- 
GROUP BY
    c.CustomerID,
    c.CustomerName;
GO


-- =========================================================
-- 9. Loan analysis by facility
-- =========================================================

SELECT
    f.FacilityID,
    COUNT(l.LoanID) AS Number_Of_Loans,
    COUNT(CASE WHEN l.LoanStatus = 'Active' THEN 1 END) AS ActiveLoanCount,
    SUM(l.DisbursedAmount) AS TotalDisbursedAmount
FROM Facilities f
INNER JOIN Loans l
    ON f.FacilityID = l.FacilityID
WHERE f.Customer_Exists = 'True' -- 
GROUP BY f.FacilityID;
GO


-- =========================================================
-- 10. Payment status summary
-- =========================================================

SELECT
    p.Status,
    COUNT(p.PaymentID) AS PaymentCount,
    SUM(p.Amount) AS TotalAmount,
    AVG(p.Amount) AS AveragePayment
FROM Payments p
INNER JOIN Facilities f
    ON p.FacilityID = f.FacilityID -- 
WHERE f.Customer_Exists = 'True' -- 
  AND p.FacilityIDExists = 'True' -- 
  AND p.AmountMissing = 'False' -- 
  AND p.StatusMissing = 'False' -- 
GROUP BY p.Status;
GO


-- =========================================================
-- 11. Payment Performance
-- =========================================================

SELECT
    c.CustomerID,
    c.CustomerName,
    COUNT(CASE WHEN p.Status = 'Partial' THEN 1 END) AS PartialPayments,
    COUNT(CASE WHEN p.Status = 'Missed' THEN 1 END) AS MissedPayments,
    COUNT(CASE WHEN p.Status = 'Ontime' THEN 1 END) AS OntimePayments,
    SUM(CASE WHEN p.AmountMissing = 'False'
             THEN p.Amount END) AS Amount
             -- Do not sum missing amounts.
FROM Customers c
INNER JOIN Facilities f
    ON c.CustomerID = f.CustomerID
LEFT JOIN Payments p
    ON p.FacilityID = f.FacilityID
    AND p.FacilityIDExists = 'True' -- 
    AND p.AmountMissing = 'False' -- 
    AND p.StatusMissing = 'False' -- 
    AND p.PaymentDateMissingOrInvalid = 'False' -- 
WHERE f.Customer_Exists = 'True' -- 
GROUP BY
    c.CustomerID,
    c.CustomerName;
GO


-- =========================================================
-- 12. Net vs positive vs negative payments
-- =========================================================

SELECT
    SUM(p.Amount) AS NetPaymentAmount,
    SUM(CASE WHEN p.Amount > 0 THEN p.Amount ELSE 0 END)
        AS PositivePaymentAmount, -- 
    SUM(CASE WHEN p.Amount < 0 THEN p.Amount ELSE 0 END)
        AS NegativePaymentAmount, -- 
    COUNT(CASE WHEN p.Amount < 0 THEN 1 END)
        AS NegativePaymentCount
FROM Payments p
INNER JOIN Facilities f
    ON p.FacilityID = f.FacilityID -- 
WHERE f.Customer_Exists = 'True' -- 
  AND p.FacilityIDExists = 'True' -- 
  AND p.AmountMissing = 'False'; -- 
-- Negative payments are intentionally retained.
GO


-- =========================================================
-- 13. Approval status analysis
-- =========================================================

SELECT
    ApprovalStatus,
    COUNT(ApprovalID) AS ApprovalCount -- Add alias
FROM Approvals
GROUP BY ApprovalStatus;
GO


-- =========================================================
-- 14. Approval analysis by approver
-- =========================================================

SELECT
    ApprovedBy,
    Approved,
    Rejected,
    TotalApprovals,
    CAST(
        Approved * 100.0 / NULLIF(TotalApprovals, 0)
        AS DECIMAL(10,2)
    ) AS ApprovalRate
FROM
(
    SELECT
        a.ApprovedBy,
        COUNT(*) AS TotalApprovals, -- 
        COUNT(CASE WHEN a.ApprovalStatus = 'approved' THEN 1 END) AS Approved,
        COUNT(CASE WHEN a.ApprovalStatus = 'rejected' THEN 1 END) AS Rejected
    FROM Approvals a
    GROUP BY a.ApprovedBy
) AS a;
GO


-- =========================================================
-- 15. Collateral Coverage
-- =========================================================

WITH CollateralSummary AS
(
    SELECT
        c.FacilityID,
        SUM(c.CollateralValue) AS TotalCollateralValue
    FROM dbo.Collaterals c
    WHERE c.NegativeValueExists = 'False' -- 
      AND c.FacilityIDExists = 'True' -- 
      AND c.DuplicateExists = 'False' -- 
    GROUP BY c.FacilityID
)
SELECT
    f.FacilityID,
    f.AmountApproved,
    COALESCE(cs.TotalCollateralValue, 0) AS TotalCollateralValue,
    CAST(
        100.0 * COALESCE(cs.TotalCollateralValue, 0)
        / NULLIF(f.AmountApproved, 0)
        AS DECIMAL(10,2)
    ) AS CollateralCoveragePct -- 
FROM dbo.Facilities f
LEFT JOIN CollateralSummary cs
    ON f.FacilityID = cs.FacilityID
WHERE f.Customer_Exists = 'True' -- 
  AND f.AmountApproved > 0; -- 
GO


-- =========================================================
-- 16.1 Covenant analysis by type
-- =========================================================

SELECT
    cc.CovenantType,
    COUNT(cc.CovenantID) AS CovenantCount,
    AVG(cc.Threshold) AS AverageThreshold,
    MAX(cc.LastCheckedDate) AS LastCheckedDate -- 
FROM Covenant_Checks cc
INNER JOIN Facilities f
    ON cc.FacilityID = f.FacilityID -- 
WHERE f.Customer_Exists = 'True' -- 
GROUP BY cc.CovenantType;
GO


-- =========================================================
-- 16.2 Covenant analysis by facility
-- =========================================================

SELECT
    cc.FacilityID,
    COUNT(cc.CovenantID) AS CovenantCount,
    MAX(cc.LastCheckedDate) AS LastCheckedDate
FROM Covenant_Checks cc
INNER JOIN Facilities f
    ON cc.FacilityID = f.FacilityID -- 
WHERE f.Customer_Exists = 'True' -- 
GROUP BY cc.FacilityID;
GO
