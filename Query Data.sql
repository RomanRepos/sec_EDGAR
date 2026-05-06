SELECT
    DISTINCT name
FROM
    financialData
WHERE
    description IS NULL;



SELECT
    count(*)
FROM
    financialData;



SELECT
    *
FROM
    financialData anti
    JOIN submissions ON submissions."accessionNumber" = "financialData"."accessionNumber";



SELECT
    cd.cik,
    fd.prefix,
    cd."entityName",
    fd.units,
    fd.financialPeriod,
    fd.name,
    fd.label,
    fd.value,
    fd.description,
    form,
    endDate,
    financialYear,
    financialPeriod,
    s.filingDate,
    s.accessionNumber,
    fd.frame,
    fd."startDate"
FROM
    financialData fd,
    companyDimension cd,
    submissions s
WHERE
    cd.cik = fd.cik
    AND s.accessionNumber = fd.accessionNumber
    AND name = 'PayablesToBrokerDealersAndClearingOrganizations';




SELECT
    fd.cik,
    fd.accessionNumber,
    fd.startDate,
    fd.endDate,
    s.reportDate,
    s.filingDate,
    fd.prefix,
    s.form,
    fd.frame,
    fd.name,
    fd.units,
    fd."value",
    "arcWeight",
    "relativeDepth",
    "keyStatementRole" AS financialStatement,
    linkRole,
    "ancestor",
    descendant
FROM
    financialData fd
    LEFT OUTER JOIN submissions s ON fd.cik = s.cik
    AND fd.accessionNumber = s.accessionNumber
    INNER JOIN calculationTaxonomyHierarchy cth ON cth.cik = fd.cik
    AND cth."accessionNumber" = fd."accessionNumber"
    AND fd.name = cth.descendant
    AND cth."relativeDepth" = 1
WHERE
    s.reportDate = fd.endDate
    AND units = 'shares'
ORDER BY
    fd.cik,
    fd."accessionNumber",
    s.form,
    keyStatementRole,
    fd.frame,
    ancestor,
    arcOrder
LIMIT
    10000;



SELECT
    *
FROM
    (
        SELECT
            linkRole,
            keyStatmentRole,
            count(*) AS countlinkRoles
        FROM
            (
                SELECT
                    DISTINCT cik,
                    accessionNUmber,
                    ct.linkRole,
                    keyStatmentRole
                FROM
                    calculationTaxonomy ct
                    LEFT OUTER JOIN CalcTaxRolesClassified ctc ON ct.linkRole = ctc.linkRole
            )
        GROUP BY
            linkRole,
            keyStatmentRole
        ORDER BY
            countlinkRoles DESC
        LIMIT
            10000
    )
WHERE
    keyStatmentRole IS NULL;



SELECT
    count(*)
FROM
    (
        SELECT
            DISTINCT linkRole
        FROM
            calculationTaxonomy
    );



CREATE
OR REPLACE TABLE calculationTaxonomy AS
SELECT
    cik,
    accessionNumber,
    COALESCE(
        NULLIF(
            regexp_extract(
                REPLACE(
                    regexp_extract(linkXlinkRole, '[^/]+$'),
                    'Role_',
                    ''
                ),
                '([A-Z]{1}[A-Za-z]+)'
            ),
            ''
        ),
        REPLACE(
            regexp_extract(linkXlinkRole, '[^/]+$'),
            'Role_',
            ''
        )
    ) AS linkRole,
    REPLACE(
        regexp_extract(arcXlinkArcrole, '[^/]+$'),
        'Role_',
        ''
    ) AS arcRole,
    regexp_extract(
        REPLACE(
            REPLACE(arcXlinkFrom, 'loc_', ''),
            'Locator_',
            ''
        ),
        '^([^.]+?)_',
        1
    ) AS fromPrefix,
    COALESCE(
        NULLIF(
            regexp_extract(
                REPLACE(
                    REPLACE(arcXlinkFrom, 'loc_', ''),
                    'Locator_',
                    ''
                ),
                '([A-Z]{1}[a-z]{2,}[A-Za-z]+)',
                1
            ),
            ''
        ),
        REPLACE(
            REPLACE(arcXlinkFrom, 'loc_', ''),
            'Locator_',
            ''
        )
    ) AS fromConcept,
    regexp_extract(
        REPLACE(REPLACE(arcXlinkTo, 'loc_', ''), 'Locator_', ''),
        '^([^.]+?)_',
        1
    ) AS toPrefix,
    COALESCE(
        NULLIF(
            regexp_extract(
                REPLACE(REPLACE(arcXlinkTo, 'loc_', ''), 'Locator_', ''),
                '([A-Z]{1}[a-z]{2,}[A-Za-z]+)',
                1
            ),
            ''
        ),
        REPLACE(REPLACE(arcXlinkTo, 'loc_', ''), 'Locator_', '')
    ) AS toConcept,
    arcUse,
    arcOrder,
    arcWeight
FROM
    calculationTaxonomyRaw;
checkpoint;



ALTER TABLE
    calculationTaxonomy DROP COLUMN isPrimaryRole;
CHECKPOINT;

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



SELECT
    ct.cik,
    ct.accessionNumber,
    ct.linkRole,
    crc.keyStatementRole,
    ct.fromConcept,
    ct.toConcept,
    ct.arcOrder,
    ct.arcWeight
FROM
    calculationTaxonomy ct
    LEFT OUTER JOIN calcTaxRolesClassified crc ON crc.linkRole = ct.linkRole anti
    JOIN calculationTaxonomyHierarchy cth ON cth.cik = ct.cik
    AND cth.accessionNumber = ct.accessionNumber
WHERE
    ct.isPrimaryRole = TRUE
    AND ct.fromConcept IS NOT NULL
    AND ct.toConcept IS NOT NULL
    AND ct.fromConcept <> ct.toConcept;



ALTER TABLE
    calculationTaxonomyHierarchy DROP COLUMN keyStatementRole;

checkpoint;

CREATE TABLE calculationTaxonomyHierarchy_NEW AS
SELECT
    cth.*,
    ct.keyStatementRole
FROM
    calculationTaxonomyHierarchy cth
    LEFT OUTER JOIN (
        SELECT
            DISTINCT cik,
            accessionNumber,
            cti.linkRole,
            keyStatementRole
        FROM
            calculationTaxonomy cti
            INNER JOIN calcTaxRolesClassified ctc ON cti.linkRole = ctc.linkRole
            AND cti.isPrimaryRole = TRUE
    ) ct ON cth.cik = ct.cik
    AND cth.accessionNumber = ct.accessionNumber
    AND cth.linkRole = ct.linkRole;

DROP TABLE calculationTaxonomyHierarchy;

ALTER TABLE
    calculationTaxonomyHierarchy_NEW RENAME TO calculationTaxonomyHierarchy;

CHECKPOINT;



SELECT
    DISTINCT cik,
    accessionNumber,
    linkRoleComp,
    keyStatementRole
FROM
    (
        SELECT
            cth.cik,
            cth.accessionNumber,
            cth.linkRole AS linkRoleComp,
            ct.keyStatementRole,
            isPrimaryRole,
            cth.keyStatementRole
        FROM
            calculationTaxonomyHierarchy cth
            LEFT OUTER JOIN (
                SELECT
                    DISTINCT cik,
                    accessionNumber,
                    cti.linkRole,
                    isPrimaryRole,
                    keyStatementRole
                FROM
                    calculationTaxonomy cti
                    INNER JOIN calcTaxRolesClassified ctc ON ctc.linkRole = cti.linkRole
                    AND cti.isPrimaryRole = TRUE
            ) ct ON cth.cik = ct.cik
            AND cth.accessionNumber = ct.accessionNumber
            AND cth.linkRole = ct.linkRole
        WHERE
            cth.keyStatementRole IS NULL
        ORDER BY
            cth.cik,
            cth.accessionNumber,
            ct.keyStatementRole
    );
