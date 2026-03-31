update raw_data
SET cik = 1786835
where entityName = 'Star Mountain Lower Middle-Market Capital Corp';

update raw_data
SET cik = 1790169
where entityName = 'ZeroStack Corp.';
CHECKPOINT;


DROP TABLE IF EXISTS filter_list;
CREATE TEMP TABLE filter_list AS 
(select CONCAT('D:\EDGAR_Data_Analytics\Data\submissions\CIK', LPAD(distinctCik.cik::VARCHAR, 10, '0'), '.json') as fileNameCol from
    (select Distinct cik from raw_data where cik in (1786835, 1790169)) as distinctCik);

SELECT * from filter_list;


INSERT INTO submissions BY NAME
(SELECT   
    CAST(cik AS INTEGER) as cik,
    unnest(filings.recent.form) AS form,
    unnest(filings.recent.accessionNumber) AS accessionNumber,
    unnest(filings.recent.filingDate) AS filingDate,
    NULLIF(unnest(filings.recent.reportDate), '') AS reportDate,
    unnest(filings.recent.acceptanceDateTime) AS acceptanceDateTime
FROM
    read_json_auto(
        'D:\EDGAR_Data_Analytics\Data\submissions\CIK0001790169.json',
        filename = True
    ) AS t)
    ;

INSERT INTO companyDimension BY NAME
(SELECT
    CAST(cik AS INTEGER) as cik,
    entityType AS entityType,
    name AS organizationName,
    category AS category,
    fiscalYearEnd AS fiscalYearEnd,
    stateOfIncorporation AS stateOfIncorporation,
    true AS isLatest,
    tickers AS tickers,
    exchanges AS exchanges,
    tickers[1] AS firstTicker,
    exchanges[1] AS firstExchange,
    CAST(NULLIF(sic,'') AS INTEGER) AS sic,
    sicDescription AS sicDescription,
    addresses.business.street1 AS street1,
    addresses.business.street2 AS street2,
    addresses.business.city AS city,
    addresses.business.stateOrCountry AS stateOrCountry,
    addresses.business.zipCode AS zipCode,
    addresses.business.stateOrCountryDescription AS stateOrCountryDescription,
    addresses.business.isForeignLocation AS isForeignLocation,
    addresses.business.foreignStateTerritory AS foreignStateTerritory,
    addresses.business.country AS country,
    addresses.business.countryCode AS countryCode,
    now() AS ingested_at  
FROM
    read_json_auto(
        'D:\EDGAR_Data_Analytics\Data\submissions\CIK0001790169.json',
        filename = True
    ) AS t
);
DROP TABLE IF EXISTS filter_list;


CREATE TABLE financialData (
    cik INTEGER,
    source VARCHAR,
    financialMetric VARCHAR,
    label VARCHAR,
    description VARCHAR,
    units VARCHAR,
    financialYear INTEGER,
    financialPeriod VARCHAR,
    endDate DATE,        -- Converted from string to DATE
    accn VARCHAR,
    value DOUBLE         -- Matches pandas float64
);

DELETE FROM raw_data 
WHERE facts IS NULL;
CHECKPOINT;