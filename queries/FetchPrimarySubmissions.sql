
SELECT

    ksvh.prefix,
    ksvh.cik,
    ksvh.accessionNumber,
    ksvh.form,
    ksvh.endDate,
    ksvh.units,
    ksvh.keyStatementRole,
    ksvh.descendant,
    uhp.absoluteDepth,
    ksvh.value * ksvh.arcWeight as value,

FROM
    keyStatementsValuesAndHierarchy ksvh


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
ANTI JOIN 
    standardMetrics sm on
    ksvh.cik = sm.cik and ksvh.accessionNumber = sm.accessionNumber
    and ksvh.endDate = sm.endDate and ksvh.units = sm.units
    and ksvh.form = sm.form

WHERE
    (ksvh.relativeDepth = 1 or (ksvh.relativeDepth=0 and ksvh.highestParent=TRUE))

--AND ksvh.cik = 1102934
--AND ksvh.accessionNumber = '0001102934-21-000007'

ORDER BY 
    ksvh.prefix,
    ksvh.cik,
    ksvh.accessionNumber,
    ksvh.form,
    ksvh.endDate,
    ksvh.units,
    ksvh.keyStatementRole,
    ksvh.descendant,
    uhp.absoluteDepth
LIMIT 300
