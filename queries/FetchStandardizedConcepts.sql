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
WHERE sc.confidenceScore > 1
QUALIFY NOT list_contains(list(sc.sign) OVER 
(PARTITION BY sc.conceptName, sc.accessionNumber, sc.keyStatementRole),
    '-')

AND rank() OVER (PARTITION BY sc.conceptName,
    sc.standardLabel,
    sc.keyStatementRole,
    sc.standardLabelID,
    sc.conceptsPerStandardLabel ORDER BY sc.confidenceScore DESC) = 1
    ;