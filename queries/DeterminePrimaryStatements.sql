ALTER TABLE
    calculationTaxonomy
ADD
    COLUMN isPrimaryRole BOOLEAN DEFAULT FALSE;

CREATE OR REPLACE TEMP TABLE hasNonCondensed AS
SELECT DISTINCT
    ct.cik,
    ct.accessionNumber,
    ctc.keyStatementRole
FROM calculationTaxonomy ct
INNER JOIN calcTaxRolesClassified ctc ON ctc.linkRole = ct.linkRole
WHERE ctc.keyStatementRole IS NOT NULL
  AND LOWER(ct.linkRole) NOT LIKE '%condensed%';


WITH ranked AS (
    SELECT
    ct.cik,
    ct.accessionNumber,
    ct.linkRole,
    ctc.keyStatementRole,
    COUNT(*) AS conceptCount,
    LENGTH(ct.linkRole) AS roleLength,
    CASE WHEN LOWER(ct.linkRole) LIKE '%consolidated%' THEN 1 ELSE 0 END AS hasConsolidated,
    CASE WHEN 
        LOWER(ct.linkRole) LIKE '%parenthetical%'
        OR LOWER(ct.linkRole) LIKE '%alternate%'
        OR LOWER(ct.linkRole) LIKE '%alternative%'
        OR LOWER(ct.linkRole) LIKE '%calc%'
        OR LOWER(ct.linkRole) LIKE '%-alt'
        OR LOWER(ct.linkRole) LIKE '%unaudited%'
        OR LOWER(ct.linkRole) LIKE '%combined%'
        OR LOWER(ct.linkRole) LIKE '%interim%'
        OR (
            LOWER(ct.linkRole) LIKE '%condensed%'
            AND hnc.cik IS NOT NULL
        )
        OR (
            LOWER(ct.linkRole) LIKE '%comprehensive%'
            AND LOWER(ct.linkRole) NOT LIKE '%operationsandcomprehensive%'
            AND LOWER(ct.linkRole) NOT LIKE '%incomeandcomprehensive%'
            AND LOWER(ct.linkRole) NOT LIKE '%earningsandcomprehensive%'
            AND LOWER(ct.linkRole) NOT LIKE '%lossandcomprehensive%'
            AND LOWER(ct.linkRole) NOT LIKE '%operationsandothercomprehensive%'
            AND LOWER(ct.linkRole) NOT LIKE '%incomeandothercomprehensive%'
            AND LOWER(ct.linkRole) NOT LIKE '%earningsandothercomprehensive%'
        )
    THEN 1 ELSE 0 END AS hasPenaltyKeyword,

    -- Composite score
    (COUNT(*) * 10)
    + (CASE WHEN LOWER(ct.linkRole) LIKE '%consolidated%' THEN 15 ELSE 0 END)
    - (CASE WHEN 
        LOWER(ct.linkRole) LIKE '%parenthetical%'
        OR LOWER(ct.linkRole) LIKE '%alternate%'
        OR LOWER(ct.linkRole) LIKE '%alternative%'
        OR LOWER(ct.linkRole) LIKE '%calc%'
        OR LOWER(ct.linkRole) LIKE '%-alt'
        OR LOWER(ct.linkRole) LIKE '%unaudited%'
        OR LOWER(ct.linkRole) LIKE '%combined%'
        OR LOWER(ct.linkRole) LIKE '%interim%'
        OR (
            LOWER(ct.linkRole) LIKE '%condensed%'
            AND hnc.cik IS NOT NULL
        )
        OR (
            LOWER(ct.linkRole) LIKE '%comprehensive%'
            AND LOWER(ct.linkRole) NOT LIKE '%operationsandcomprehensive%'
            AND LOWER(ct.linkRole) NOT LIKE '%incomeandcomprehensive%'
            AND LOWER(ct.linkRole) NOT LIKE '%earningsandcomprehensive%'
            AND LOWER(ct.linkRole) NOT LIKE '%lossandcomprehensive%'
            AND LOWER(ct.linkRole) NOT LIKE '%operationsandothercomprehensive%'
            AND LOWER(ct.linkRole) NOT LIKE '%incomeandothercomprehensive%'
            AND LOWER(ct.linkRole) NOT LIKE '%earningsandothercomprehensive%'
        )
       THEN 20 ELSE 0 END)
    - (LENGTH(ct.linkRole) / 10)
    AS compositeScore,

    ROW_NUMBER() OVER (
        PARTITION BY ct.cik, ct.accessionNumber, ctc.keyStatementRole
        ORDER BY
            (COUNT(*) * 10)
            + (CASE WHEN LOWER(ct.linkRole) LIKE '%consolidated%' THEN 15 ELSE 0 END)
            - (CASE WHEN 
                LOWER(ct.linkRole) LIKE '%parenthetical%'
                OR LOWER(ct.linkRole) LIKE '%alternate%'
                OR LOWER(ct.linkRole) LIKE '%alternative%'
                OR LOWER(ct.linkRole) LIKE '%calc%'
                OR LOWER(ct.linkRole) LIKE '%-alt'
                OR LOWER(ct.linkRole) LIKE '%unaudited%'
                OR LOWER(ct.linkRole) LIKE '%combined%'
                OR LOWER(ct.linkRole) LIKE '%interim%'
                OR (
                    LOWER(ct.linkRole) LIKE '%condensed%'
                    AND hnc.cik IS NOT NULL
                )
                OR (
                    LOWER(ct.linkRole) LIKE '%comprehensive%'
                    AND LOWER(ct.linkRole) NOT LIKE '%operationsandcomprehensive%'
                    AND LOWER(ct.linkRole) NOT LIKE '%incomeandcomprehensive%'
                    AND LOWER(ct.linkRole) NOT LIKE '%earningsandcomprehensive%'
                    AND LOWER(ct.linkRole) NOT LIKE '%lossandcomprehensive%'
                    AND LOWER(ct.linkRole) NOT LIKE '%operationsandothercomprehensive%'
                    AND LOWER(ct.linkRole) NOT LIKE '%incomeandothercomprehensive%'
                    AND LOWER(ct.linkRole) NOT LIKE '%earningsandothercomprehensive%'
                )
               THEN 20 ELSE 0 END)
            - (LENGTH(ct.linkRole) / 10)
            DESC
    ) AS rn

FROM calculationTaxonomy ct
INNER JOIN calcTaxRolesClassified ctc ON ctc.linkRole = ct.linkRole
LEFT JOIN hasNonCondensed hnc
    ON hnc.cik = ct.cik
    AND hnc.accessionNumber = ct.accessionNumber
    AND hnc.keyStatementRole = ctc.keyStatementRole
WHERE ctc.keyStatementRole IS NOT NULL
GROUP BY
    ct.cik,
    ct.accessionNumber,
    ct.linkRole,
    ctc.keyStatementRole,
    hnc.cik
)
UPDATE
    calculationTaxonomy
SET
    isPrimaryRole = TRUE
FROM
    ranked
WHERE
    ranked.rn = 1
    AND calculationTaxonomy.cik = ranked.cik
    AND calculationTaxonomy.accessionNumber = ranked.accessionNumber
    AND calculationTaxonomy.linkRole = ranked.linkRole;

CHECKPOINT;