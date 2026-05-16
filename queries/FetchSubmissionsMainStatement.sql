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
    LEFT OUTER JOIN calculationTaxonomyHierarchy ctht ON ctht.cik = fd.cik
    AND ctht."accessionNumber" = fd."accessionNumber"
    AND cth.ancestor = ctht.ancestor
    AND ctht."relativeDepth" = 0
    AND ctht.highestParent = TRUE
WHERE
    
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
    and cth."keyStatementRole" IN (
        'BalanceSheet',
        'IncomeStatement',
        'StatementOfCashFlows'
    )
    AND fd.units = ?
    AND fd.isPrimarySubmissionDateRange = TRUE
    and fd.isPrimaryUnits = TRUE
    AND fd.isPrimaryPrefix = TRUE
ORDER BY
    cth.keyStatementRole,
    cth.ancestor,
    cth.arcWeight DESC