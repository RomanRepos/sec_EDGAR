WITH standardrizedConceptsParents AS (
    SELECT
        DISTINCT 
        cth.ancestor,
        sc.conceptName,
        sc.standardLabel,
        cth.keyStatementRole,
        cth.relativeDepth
    FROM
        standardizedConcepts sc
        INNER JOIN calculationTaxonomyHierarchy cth ON sc.cik = cth.cik
        AND sc.accessionNumber = cth.accessionNumber
        AND sc.conceptName = cth.descendant
        AND cth.keyStatementRole = sc.keyStatementRole
        AND (
            cth.relativeDepth = 1
            OR cth.relativeDepth = 0
        )
)


SELECT
    ksvh.prefix,
    ksvh.cik,
    ksvh.accessionNumber,
    ksvh.form,
    ksvh.endDate,
    ksvh.units,
    ksvh.keyStatementRole,
    ksvh.descendant,
    scp.standardLabel,
    uhp.absoluteDepth,
    ksvh.value
FROM
    keyStatementsValuesAndHierarchy ksvh
    INNER JOIN standardrizedConceptsParents scp ON ksvh.descendant = scp.conceptName
    AND ksvh.ancestor = scp.ancestor
    AND ksvh.keyStatementRole = scp.keyStatementRole
    AND ksvh.relativeDepth = scp.relativeDepth
    AND (ksvh.relativeDepth = 1 or (ksvh.relativeDepth=0 and ksvh.highestParent=TRUE))
    INNER JOIN (
        SELECT
            cth1.cik,
            cth1.accessionNumber,
            cth1.descendant,
            cth1.relativeDepth AS absoluteDepth,
            cth1.keyStatementRole
        FROM
            calculationTaxonomyHierarchy AS cth1
            INNER JOIN calculationTaxonomyHierarchy AS cth2 ON cth1.cik = cth2.cik
            AND cth1.accessionNumber = cth2.accessionNumber
            AND cth1.keyStatementRole = cth2.keyStatementRole
            AND cth1.ancestor = cth2.ancestor
            AND cth2.highestParent = TRUE
    ) uhp ON ksvh.cik = uhp.cik
    AND ksvh.accessionNumber = uhp.accessionNumber
    AND ksvh.keyStatementRole = uhp.keyStatementRole
    AND ksvh.descendant = uhp.descendant
    ANTI JOIN (SELECT DISTINCT cik, accessionNumber from standardizedConcepts) scs
    on scs.cik = ksvh.cik and scs.accessionNumber = ksvh.accessionNumber

/*
WHERE
    ksvh.cik = 1750
    AND ksvh.accessionNumber = '0001047469-11-006302'
*/
ORDER BY
    ksvh.cik,
    ksvh.accessionNumber,
    ksvh.form,
    ksvh.keyStatementRole,
    scp.standardLabel,
    ksvh.descendant
LIMIT 100000
    