with
    sc as (
        SELECT DISTINCT
            conceptName,
            standardLabel,
            standardLabelID,
            conceptsPerStandardLabel,
            confidenceScore,
            keyStatementRole
        FROM
            standardizedConcepts sc
        WHERE
            standardLabel = 'Net Income'
            AND confidenceScore >= 2
            --AND standardLabel = 'Depreciation and Amortization'
            --AND keyStatementRole IN ('StatementOfCashFlows', 'IncomeStatement') 
            --AND keyStatementRole = 'BalanceSheet'
            QUALIFY NOT list_contains (
                list (sc.sign) OVER (
                    PARTITION BY
                        sc.cik,
                        sc.accessionNumber,
                        sc.keyStatementRole,
                        sc.standardLabelID
                ),
                '-'
            )
    )
SELECT
/*
    fd.prefix,
    fd.cik,
    fd.name as conceptName,
    fd.units,
    fd.endDate,
    s.form,
    sc.confidenceScore,
    fd.name AS conceptName,
    sc.conceptsPerStandardLabel,
    sc.standardLabel,
    sc.standardLabelID,
    sc.keyStatementRole,
    fd.value
    */
    count(*)
FROM
    financialData fd
    INNER JOIN sc ON sc.conceptName = fd.name
    INNER JOIN submissions s ON s.accessionNumber = fd.accessionNumber
    AND fd.cik = s.cik
    AND s.reportDate = fd.endDate
    --AND sm."Depreciation and Amortization" IS NULL
   
where
    fd.isPrimarySubmissionDateRange = TRUE
    and fd.isPrimaryPrefix = TRUE
    and fd.isPrimaryUnits = TRUE
    AND s.form in (
        '10-K',
        '20-F',
        '40-F',
        '10-K/A',
        '20-F/A',
        '40-F/A',
        '10-Q',
        '10-Q/A'
    )
    AND prefix in ('us-gaap', 'ifrs-full');



    SELECT DISTINCT
            conceptName,
            standardLabel,
            standardLabelID,
            conceptsPerStandardLabel,
            confidenceScore,
            keyStatementRole
        FROM
            standardizedConcepts sc
        WHERE
            standardLabel = 'Total Assets'
            AND confidenceScore >= 1
            AND "conceptsPerStandardLabel" <= 4
            --AND standardLabel = 'Depreciation and Amortization'
            --AND keyStatementRole IN ('StatementOfCashFlows', 'IncomeStatement') 
            --AND keyStatementRole = 'BalanceSheet'
            QUALIFY NOT list_contains (
                list (sc.sign) OVER (
                    PARTITION BY
                        sc.cik,
                        sc.accessionNumber,
                        sc.keyStatementRole,
                        sc.standardLabelID
                ),
                '-'
            );