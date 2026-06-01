SET threads = 2;
SET memory_limit = '16GB';
SET preserve_insertion_order = false;
SET max_temp_directory_size = '150GB';
with
    sc as (
        SELECT DISTINCT
            sc.conceptName,
            sc.standardLabel,
            sc.standardLabelID,
            sc.conceptsPerStandardLabel,
            sc.confidenceScore,
            sc.keyStatementRole
        FROM
            standardizedConcepts sc
        INNER JOIN standardLineItems sli on
            sli.standardLabel = sc.standardLabel
        WHERE
            1=1
            --AND sc.standardLabel = ?
            AND sc.confidenceScore >= 2
            AND sc.conceptsPerStandardLabel <= sli.maxComponents
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
    fd.prefix,
    fd.cik,
    fd.accessionNumber,
    fd.name AS conceptName,
    fd.units,
    fd.endDate,
    s.form,
    sc.conceptsPerStandardLabel,
    sc.standardLabel,
    sc.standardLabelID,
    fd.value
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
    AND prefix in ('us-gaap', 'ifrs-full')
    ;