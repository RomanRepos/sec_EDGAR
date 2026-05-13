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

create or replace table calculationTaxonomy as
select DISTINCT * from calculationTaxonomy
where fromConcept IS NOT NULL and toConcept IS NOT NULL and fromConcept<>toConcept;
checkpoint;