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
    /*
    ANTI
    JOIN (
        SELECT
            DISTINCT cik,
            accessionNumber
        FROM
            standardizedConcepts
    ) sc ON sc.cik = ksh.cik
    AND sc.accessionNumber = ksh.accessionNumber
*/

WHERE
    ksh.allKeyStatementsPresent = TRUE
    AND ksh.rollUpIsAccurate = TRUE
ORDER BY
    ksh.keyStatementRole,
    ksh.ancestor,
    ksh.arcWeight DESC
;