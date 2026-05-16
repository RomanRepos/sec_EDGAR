SELECT
    cth."keyStatementRole" AS financialStatement,
    cth."ancestor",
    cth.descendant,
    cth."arcWeight",
    cth.relativeDepth
FROM
    financialData fd
    INNER JOIN submissions s ON fd.cik = s.cik
    AND fd.accessionNumber = s.accessionNumber
    AND s.reportDate = fd.endDate
    INNER JOIN calculationTaxonomyHierarchy cth ON cth.cik = fd.cik
    AND cth.accessionNumber = fd.accessionNumber
    AND fd.name = cth.descendant
WHERE
    fd.prefix = ?
    AND fd.cik = ?
    AND fd.accessionNumber = ?
    AND (
        cth."relativeDepth" = 1
        OR (
            cth."relativeDepth" = 0
            AND cth.highestParent = TRUE
        )
    )
    AND s.form = ?
    AND fd.endDate = ?
    AND cth."keyStatementRole" IN (
        'BalanceSheet',
        'IncomeStatement',
        'StatementOfCashFlows'
    )
    AND fd.units = ?
    AND fd.isPrimarySubmissionDateRange = TRUE
    AND fd.isPrimaryUnits = TRUE
    AND fd.isPrimaryPrefix = TRUE
ORDER BY
    cth.keyStatementRole,
    cth.ancestor,
    cth.arcWeight DESC