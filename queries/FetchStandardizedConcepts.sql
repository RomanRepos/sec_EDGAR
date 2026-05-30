SELECT 
    DISTINCT
    sc.conceptName,
    sc.standardLabel,
    sc.keyStatementRole,
    sc.standardLabelID,
    sc.conceptsPerStandardLabel,
    sc.confidenceScore
FROM

    standardizedConcepts sc
WHERE sc.confidenceScore = 3
QUALIFY NOT list_contains(list(sc.sign) OVER 
(PARTITION BY sc.cik, sc.accessionNumber, sc.keyStatementRole, sc.standardLabelID),
    '-')

AND rank() OVER (PARTITION BY sc.conceptName,
    sc.standardLabel,
    sc.keyStatementRole,
    sc.standardLabelID,
    sc.conceptsPerStandardLabel ORDER BY sc.confidenceScore DESC) = 1

    limit 100
    ;