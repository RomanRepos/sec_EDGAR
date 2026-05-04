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
    count(*) AS uniqueDescr
FROM
    (
        SELECT
            DISTINCT label
        FROM
            financialData
    );



SELECT
    DISTINCT name,
    label,
    description
FROM
    financialData
ORDER BY
    name;



SELECT
    *
FROM
    companyDimension
WHERE
    firstTicker = 'MSFT';



SELECT
    companyDimension.cik,
    fd_gaap.prefix,
    fd_ifrs.prefix
FROM
    companyDimension
    LEFT OUTER JOIN (
        SELECT
            DISTINCT cik,
            prefix
        FROM
            financialData
        WHERE
            prefix = 'us-gaap'
    ) AS fd_gaap ON companyDimension.cik = fd_gaap.cik
    LEFT OUTER JOIN (
        SELECT
            DISTINCT cik,
            prefix
        FROM
            financialData
        WHERE
            prefix = 'ifrs-full'
    ) AS fd_ifrs ON companyDimension.cik = fd_ifrs.cik;



SELECT
    count(*)
FROM
    (
        SELECT
            DISTINCT name
        FROM
            financialData
        WHERE
            prefix = 'us-gaap'
    ) AS gaapCount;



SELECT
    count(*)
FROM
    (
        SELECT
            DISTINCT ancestorName
        FROM
            calculationTaxonomy
        WHERE
            ancestorPrefix = 'us-gaap'
    ) AS gaapCount;



SELECT
    cik,
    accessionNumber,
    startDate,
    endDate,
    name,
    units,
    prefix,
    COUNT(*) AS occurrence_count
FROM
    financialData
GROUP BY
    accessionNumber,
    name,
    startDate,
    endDate,
    units,
    cik,
    prefix
HAVING
    COUNT(*) > 1
ORDER BY
    accessionNumber,
    occurrence_count DESC;



SELECT
    name,
    count(*) AS count
FROM
    (
        SELECT
            DISTINCT name
        FROM
            financialData
    ) AS financialData
    LEFT OUTER JOIN (
        SELECT
            DISTINCT definition,
            ancestorName
        FROM
            calculationTaxonomyHierarchy
    ) AS ct ON financialData.name = ct.ancestorName
GROUP BY
    name
HAVING
    count > 1
ORDER BY
    count DESC;



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
    "keyStatementRole",
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
    fd.cik = 1750
    AND fd.accessionNumber = '0001047469-11-006302'
    AND s.reportDate = fd.endDate
ORDER BY
    fd.cik,
    fd."accessionNumber",
    s.form,
    keyStatementRole,
    fd.frame,
    ancestor,
    arcOrder;



SELECT
    ancestor,
    descendant
FROM
    calculationTaxonomyHierarchy
WHERE
    descendant = 'StockholdersEquityIncludingPortionAttributableToNoncontrollingInterest'
    AND cik = 1750
    AND accessionNumber = '0001047469-11-006302';



SELECT
    prefix,
    financialData.cik,
    name,
    value,
    units,
    partitionNumber,
    startDate,
    endDate,
    form,
    frame,
    submissions.accessionNumber
FROM
    financialData
    LEFT OUTER JOIN submissions ON financialData.accessionNumber = submissions.accessionNumber
WHERE
    prefix = 'ifrs-full'
ORDER BY
    partitionNumber,
    name;



SELECT
    count(*)
FROM
    (
        SELECT
            DISTINCT cik,
            accessionNumber
        FROM
            financialData
    ) AS subCount;



SELECT
    linkXlinkRole,
    count(*) AS countRoles
FROM
    calculationTaxonomyRaw
GROUP BY
    linkXlinkRole
ORDER BY
    countRoles DESC;



SELECT
    toConcept,
    count(*) AS countToConcepts
FROM
    calculationTaxonomy
WHERE
    toConcept = ''
    OR toConcept IS NULL
GROUP BY
    toConcept
ORDER BY
    countToConcepts DESC;



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



SELECT
    ct.cik,
    ct.accessionNumber,
    ct.linkRole,
    ct.fromConcept,
    ct.toConcept,
    ct.arcOrder,
    ct.arcWeight
FROM
    calculationTaxonomy ct anti
    JOIN calculationTaxonomyHierarchy cth ON cth.cik = ct.cik
    AND cth.accessionNumber = ct.accessionNumber
WHERE
    ct.isPrimaryRole = TRUE
    AND ct.fromConcept IS NOT NULL
    AND ct.toConcept IS NOT NULL
    AND ct.fromConcept <> ct.toConcept;



/*
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
    calculationTaxonomy
ADD
    COLUMN isPrimaryRole BOOLEAN DEFAULT FALSE;



WITH ranked AS (
    SELECT
        cik,
        accessionNumber,
        ct.linkRole,
        ROW_NUMBER() OVER (
            PARTITION BY cik,
            accessionNumber,
            ctc.keyStatementRole
            ORDER BY
                COUNT(*) DESC
        ) AS rn
    FROM
        calculationTaxonomy ct
        INNER JOIN calcTaxRolesClassified ctc ON ctc.linkRole = ct.linkRole
    WHERE
        ctc.keyStatementRole IS NOT NULL
    GROUP BY
        cik,
        accessionNumber,
        ct.linkRole,
        ctc.keyStatementRole
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

*/

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