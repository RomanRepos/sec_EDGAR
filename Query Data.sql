SELECT
    cth."keyStatementRole" AS financialStatement,
    cth."ancestor",
    cth.descendant,
    cth."arcWeight",
    cth.relativeDepth,
    cth."ancestor",
    cth.descendant,
    cth."arcWeight",
    cth.relativeDepth,
    fd."value",
    fd.units,
    ctht.highestParent,
    s.form,
    fd.endDate,
    fd.frame
FROM
    financialData fd
    INNER JOIN submissions s
        ON fd.cik = s.cik
        AND fd.accessionNumber = s.accessionNumber
        AND s.reportDate = fd.endDate
        AND FD.isStandardPeriodLength = TRUE
    INNER JOIN calculationTaxonomyHierarchy cth
        ON cth.cik = fd.cik
        AND cth.accessionNumber = fd.accessionNumber
        AND fd.name = cth.descendant
    LEFT OUTER JOIN calculationTaxonomyHierarchy ctht
        ON ctht.cik = fd.cik
        AND ctht."accessionNumber" = fd."accessionNumber"
        AND cth.ancestor = ctht.ancestor
        AND ctht."relativeDepth" = 0
        AND ctht.highestParent = TRUE
WHERE
--us-gaap 744825 0001144204-12-018468 10-K 2011-12-31
    fd.prefix = 'us-gaap'
    AND fd.cik = 8063
    AND fd.accessionNumber = '0000008063-20-000042'
    AND (cth."relativeDepth" = 1 OR (cth."relativeDepth" = 0 AND cth.highestParent = TRUE))
    AND s.form = '10-Q'
    AND fd.endDate = '2020-06-27'
    AND cth.relativeDepth <= 2
ORDER BY
    cth.keyStatementRole,
    cth.ancestor,
    cth.arcWeight DESC;


--Determine submissions that have matching total for top level parents and first level nodes for each key statement role to identify filings with complete calculation hierarchies for primary financial statements.
with topLevelParentsSum as (
SELECT fd.prefix, cth.cik, cth.accessionNumber, 
cth.linkRole, 
cth.keyStatementRole, s.form, fd.endDate, sum(fd.value) highestLevelParentsTotal 
from calculationTaxonomyHierarchy cth 
inner join financialData fd on
    fd.cik = cth.cik 
    --AND form ='10-K'
    AND fd.accessionNumber = cth.accessionNumber
    AND fd.name = cth.descendant
    AND cth.relativeDepth = 0
    AND cth.highestParent = TRUE
    AND fd.prefix = 'us-gaap'
    AND fd.isPrimarySubmissionDateRange = TRUE
INNER JOIN submissions s 
        ON fd.cik = s.cik 
        --AND form ='10-K'
        AND fd.accessionNumber = s.accessionNumber
        AND s.reportDate = fd.endDate
GROUP BY
    fd.prefix, cth.cik, cth.accessionNumber, cth.linkRole, cth.keyStatementRole, s.form, fd.endDate
), 

firstLevelNodestSum as (
SELECT fd.prefix, cth.cik, cth.accessionNumber, cth.linkRole,  
cth.keyStatementRole, s.form, fd.endDate, sum(fd.value*cth.arcWeight) firstLevelNodesTotal 
from calculationTaxonomyHierarchy cth
inner join financialData fd on
    fd.cik = cth.cik 
    --AND form ='10-K'
    AND fd.accessionNumber = cth.accessionNumber
    AND fd.name = cth.descendant
    AND cth.relativeDepth = 1
    AND fd.prefix = 'us-gaap'
    AND fd.isPrimarySubmissionDateRange = TRUE
INNER JOIN submissions s 
        ON fd.cik = s.cik 
        --AND form ='10-K'
        AND fd.accessionNumber = s.accessionNumber
        AND s.reportDate = fd.endDate
INNER JOIN calculationTaxonomyHierarchy ctht
        ON ctht.cik = cth.cik
        AND ctht."accessionNumber" = cth."accessionNumber"
        AND cth.ancestor = ctht.ancestor
        AND ctht."relativeDepth" = 0
        AND ctht.highestParent = TRUE
GROUP BY
    fd.prefix, cth.cik, cth.accessionNumber, cth.linkRole, cth.keyStatementRole, s.form, fd.endDate
)     

select count(*) from (
select tlp.prefix,tlp.cik, tlp.accessionNumber, tlp.form, tlp.endDate from topLevelParentsSum tlp
INNER JOIN firstLevelNodestSum fln 
on tlp.cik = fln.cik
and tlp.accessionNumber = fln.accessionNumber
and tlp.linkRole = fln.linkRole
and tlp.keyStatementRole = fln.keyStatementRole
and tlp.form = fln.form
and tlp.endDate = fln.endDate
and tlp.highestLevelParentsTotal = fln.firstLevelNodesTotal
WHERE tlp.keyStatementRole in ('BalanceSheet', 'IncomeStatement', 'StatementOfCashFlows')
GROUP BY tlp.prefix, tlp.cik, tlp.accessionNumber, tlp.form, tlp.endDate
HAVING count(*) = 3
ORDER BY tlp.prefix, tlp.cik, tlp.accessionNumber, tlp.form, tlp.endDate)
;
--------------------------------------------------------------------------------



SELECT ct.linkRole, isPrimaryRole, ctc.keyStatementRole, fromConcept from calculationTaxonomy ct
left outer join calcTaxRolesClassified ctc
on ctc.linkRole = ct.linkRole
where ct.accessionNumber = '0000008063-20-000042'
;

select  startDate, endDate, isStandardPeriodLength from financialData where 
--accessionNumber = '0000008063-20-000042'
--and name LIKE '%GrossProfit%' and endDate = '2020-06-27' AND i
isStandardPeriodLength = TRUE
order by name asc
LIMIT 1000;

select * from submissions where accessionNumber = '0000008063-20-000042';

select distinct keystatementRole from calculationTaxonomyHierarchy
;


CHECKPOINT;
/*
--Remove duplicate rows from hierarchy table that may have been caused by multiple statement roles per link role. We want to keep the one with the greatest relative depth to ensure we are capturing the most specific role for each link role.
CREATE TABLE calculationTaxonomyHierarchy_NEW as
SELECT * FROM calculationTaxonomyHierarchy 
QUALIFY ROW_NUMBER() OVER 
(PARTITION BY 
cik,
accessionNumber,
linkRole,
ancestor,
descendant,
arcOrder,
arcWeight,
highestParent,
lowestChild,
keyStatementRole
ORDER BY relativeDepth DESC) = 1
;
DROP TABLE calculationTaxonomyHierarchy;
ALTER TABLE calculationTaxonomyHierarchy_NEW RENAME to calculationTaxonomyHierarchy;
CHECKPOINT;
------------------------------------------------------------------------
*/



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

--Create calculationTaxonomy table with parsed link roles, arc roles, from/to concepts, and other relevant fields for analysis.
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
                '([A-]{1}[A-a-]+)'
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
                '([A-]{1}[a-]{2,}[A-a-]+)',
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
                '([A-]{1}[a-]{2,}[A-a-]+)',
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
------------------------------------------------------------



---Classify statement roles and identify primary role for each key statement role.
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
----------------------------------------------------------------------------


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


--Make sure hierarchy table only has primary statement roles.
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
------------------------------------------------------


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
