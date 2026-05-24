

SELECT  
    DISTINCT ksh.prefix,
    ksh.cik,
    ksh.accessionNumber,
    ksh.form,
    ksh.endDate,
    ksh.units,
    ksh.descendant AS conceptName
FROM
    keyStatementsValuesAndHierarchy ksh

    ANTI
    JOIN (
        SELECT
            DISTINCT cik,
            accessionNumber
        FROM
            standardizedConcepts
    ) sc ON sc.cik = ksh.cik
    AND sc.accessionNumber = ksh.accessionNumber

    INNER JOIN standardMetrics sm
    ON 
    sm.cik = ksh.cik and sm.accessionNumber = ksh.accessionNumber
    and sm.form = ksh.form
    AND sm.prefix = ksh.prefix
    AND sm.units = ksh.units
    AND sm.endDate = ksh.endDate

WHERE
    ksh.allKeyStatementsPresent = TRUE

    --AND ksh.rollUpIsAccurate = TRUE
    AND (
        (
            CASE WHEN sm."Revenue" IS NULL THEN 1 ELSE 0 END +
            CASE WHEN sm."Cost of Revenue" IS NULL THEN 1 ELSE 0 END +
            CASE WHEN sm."Gross Profit" IS NULL THEN 1 ELSE 0 END +
            CASE WHEN sm."Research and Development Expenses" IS NULL THEN 1 ELSE 0 END +
            CASE WHEN sm."Selling, General and Administrative Expenses" IS NULL THEN 1 ELSE 0 END +
            CASE WHEN sm."Operating Expenses" IS NULL THEN 1 ELSE 0 END +
            CASE WHEN sm."Operating Income" IS NULL THEN 1 ELSE 0 END +
            CASE WHEN sm."Interest Expense" IS NULL THEN 1 ELSE 0 END +
            CASE WHEN sm."Interest Income" IS NULL THEN 1 ELSE 0 END +
            CASE WHEN sm."Pre-tax Income" IS NULL THEN 1 ELSE 0 END +
            CASE WHEN sm."Income Tax Expense" IS NULL THEN 1 ELSE 0 END +
            CASE WHEN sm."Net Income" IS NULL THEN 1 ELSE 0 END +
            CASE WHEN sm."Cash and Cash Equivalents" IS NULL THEN 1 ELSE 0 END +
            CASE WHEN sm."Accounts Receivable" IS NULL THEN 1 ELSE 0 END +
            CASE WHEN sm."Inventory" IS NULL THEN 1 ELSE 0 END +
            CASE WHEN sm."Total Current Assets" IS NULL THEN 1 ELSE 0 END +
            CASE WHEN sm."Property, Plant and Equipment, Net" IS NULL THEN 1 ELSE 0 END +
            CASE WHEN sm."Goodwill" IS NULL THEN 1 ELSE 0 END +
            CASE WHEN sm."Intangible Assets" IS NULL THEN 1 ELSE 0 END +
            CASE WHEN sm."Total Assets" IS NULL THEN 1 ELSE 0 END +
            CASE WHEN sm."Accounts Payable" IS NULL THEN 1 ELSE 0 END +
            CASE WHEN sm."Short-term Borrowings" IS NULL THEN 1 ELSE 0 END +
            CASE WHEN sm."Current Portion of Long-term Debt" IS NULL THEN 1 ELSE 0 END +
            CASE WHEN sm."Deferred Revenue" IS NULL THEN 1 ELSE 0 END +
            CASE WHEN sm."Total Current Liabilities" IS NULL THEN 1 ELSE 0 END +
            CASE WHEN sm."Long-term Debt" IS NULL THEN 1 ELSE 0 END +
            CASE WHEN sm."Total Debt" IS NULL THEN 1 ELSE 0 END +
            CASE WHEN sm."Total Liabilities" IS NULL THEN 1 ELSE 0 END +
            CASE WHEN sm."Retained Earnings" IS NULL THEN 1 ELSE 0 END +
            CASE WHEN sm."Total Equity" IS NULL THEN 1 ELSE 0 END +
            CASE WHEN sm."Operating Cash Flow" IS NULL THEN 1 ELSE 0 END +
            CASE WHEN sm."Depreciation and Amortization" IS NULL THEN 1 ELSE 0 END +
            CASE WHEN sm."Stock-based Compensation" IS NULL THEN 1 ELSE 0 END +
            CASE WHEN sm."Capital Expenditures" IS NULL THEN 1 ELSE 0 END +
            CASE WHEN sm."Dividends Paid" IS NULL THEN 1 ELSE 0 END
        ) >= 7

        OR sm."Revenue" IS NULL
        OR sm."Cost of Revenue" IS NULL
        OR sm."Net Income" IS NULL
        OR sm."Total Assets" IS NULL
        OR sm."Total Liabilities" IS NULL
        OR sm."Operating Cash Flow" IS NULL
        )

ORDER BY
    ksh.keyStatementRole,
    ksh.ancestor,
    ksh.arcWeight DESC
;
