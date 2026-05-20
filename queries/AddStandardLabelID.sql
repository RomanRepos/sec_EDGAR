ALTER TABLE
    standardizedConcepts
ADD
    COLUMN IF NOT EXISTS standardLabelID VARCHAR;



ALTER TABLE
    standardizedConcepts
ADD
    COLUMN IF NOT EXISTS conceptsPerStandardLabel INTEGER;



ALTER TABLE
    standardizedConcepts
ADD
    COLUMN IF NOT EXISTS confidenceScore INTEGER;



UPDATE
    standardizedConcepts
SET
    standardLabelID = sub.standardLabelID
FROM
    (
        SELECT
            rowid,
            string_agg(
                conceptName,
                '|'
                ORDER BY
                    conceptName
            ) OVER (
                PARTITION BY prefix,
                cik,
                accessionNumber,
                units,
                form,
                endDate,
                keyStatementRole,
                standardLabel
            ) AS standardLabelID
        FROM
            standardizedConcepts
    ) AS sub
WHERE
    sub.rowid = standardizedConcepts.rowid;



UPDATE
    standardizedConcepts
SET
    conceptsPerStandardLabel = sub.conceptsPerStandardLabel
FROM
    (
        SELECT
            rowid,
            count() OVER (
                PARTITION BY prefix,
                cik,
                accessionNumber,
                units,
                form,
                endDate,
                keyStatementRole,
                standardLabel
            ) AS conceptsPerStandardLabel
        FROM
            standardizedConcepts
    ) AS sub
WHERE
    sub.rowid = standardizedConcepts.rowid;



UPDATE
    standardizedConcepts
SET
    confidenceScore = CASE
        confidenceLevel
        WHEN 'low' THEN 1
        WHEN 'medium' THEN 2
        WHEN 'high' THEN 3
    END;



CHECKPOINT;