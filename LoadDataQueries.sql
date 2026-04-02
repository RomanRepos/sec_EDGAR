SET VARIABLE facts_path = '{{facts_path_param}}';
SET VARIABLE submissions_path = '{{submissions_path_param}}';

--Load raw data from company facts
CREATE OR REPLACE TABLE raw_data AS
SELECT
CAST(Left(Right(filename, 15), 10) AS INTEGER)::INTEGER AS cik,
(json->'$.facts')::JSON AS facts
FROM read_json_objects(CONCAT(getvariable('facts_path'),'*.json'), filename=True);

--add last modified file for companyfacts
ALTER TABLE raw_data ADD COLUMN lastModified TIMESTAMPTZ;
ALTER TABLE raw_data ADD COLUMN fileNameCol VARCHAR;

UPDATE raw_data
SET fileNameCol  = CONCAT(getvariable('facts_path'), 'CIK', LPAD(cik::VARCHAR, 10, '0'), '.json');


with fileNameMeta as (SELECT filename, last_modified 
    FROM read_text(CONCAT(getvariable('facts_path'),'*.json')))
UPDATE raw_data
SET lastModified = fileNameMeta.last_modified
FROM fileNameMeta
WHERE raw_data.fileNameCol = fileNameMeta.filename;
ALTER TABLE raw_data DROP COLUMN fileNameCol;

DELETE FROM raw_data 
WHERE facts IS NULL or facts='{}' or cik is NULL;


CREATE OR REPLACE TEMP TABLE filter_list AS
(select distinct cik as cik from raw_data);
CHECKPOINT;

CREATE OR REPLACE TABLE submissions AS
SELECT
    CAST(cik AS INTEGER)::INTEGER as cik,
    unnest(filings.recent.form)::VARCHAR AS form,
    unnest(filings.recent.accessionNumber)::VARCHAR AS accessionNumber,
    unnest(filings.recent.filingDate)::DATE AS filingDate,
    NULLIF(unnest(filings.recent.reportDate), '')::DATE AS reportDate,
    unnest(filings.recent.acceptanceDateTime)::TIMESTAMPTZ AS acceptanceDateTime
FROM
    read_json_auto(
        CONCAT(getvariable('submissions_path'),'*.json'),
        filename = True
    ) AS t
WHERE
    EXISTS( SELECT 1 FROM filter_list f WHERE CAST(cik AS INTEGER) = f.cik )
    AND t.filename NOT LIKE '%-submissions-%.json' 
    ;
CHECKPOINT;

INSERT INTO submissions
SELECT
    CAST(Left(Right(filename, 31), 10) AS INTEGER) AS cik,
    unnest(form) AS form,
    unnest(accessionNumber) AS accessionNumber,
    unnest(filingDate) AS filingDate,
    NULLIF(unnest(reportDate), '') AS reportDate,
    unnest(acceptanceDateTime) AS acceptanceDateTime
FROM
    read_json_auto(
        CONCAT(getvariable('submissions_path'),'*.json'),
        filename = True
    ) AS t
WHERE
    EXISTS( SELECT 1 FROM filter_list f WHERE CAST(Left(Right(t.filename, 31), 10) AS INTEGER) = f.cik ) and t.filename LIKE '%-submissions-%.json';
CHECKPOINT;


--load  copmpany dimesions table from submission files where facts exist
SET memory_limit = "25GB";
CREATE OR REPLACE TABLE companyDimension AS
SELECT
    CAST(cik AS INTEGER)::INTEGER as cik,
    entityType::VARCHAR AS entityType,
    name::VARCHAR AS entityName,
    category::VARCHAR AS category,
    fiscalYearEnd::VARCHAR AS fiscalYearEnd,
    stateOfIncorporation::VARCHAR AS stateOfIncorporation,
    true AS isLatest,
    tickers::VARCHAR[] as tickers,
    exchanges::VARCHAR[] as exchanges,
    firstTicker: tickers[1],
    firstExchange: exchanges[1],
    CAST(NULLIF(sic,'') AS INTEGER)::INTEGER as sic,
    sicDescription::VARCHAR AS sicDescription,
    addresses.business.street1::VARCHAR AS street1,
    addresses.business.street2::VARCHAR AS street2,
    addresses.business.city::VARCHAR AS city,
    addresses.business.stateOrCountry::VARCHAR AS stateOrCountry,
    addresses.business.zipCode::VARCHAR AS zipCode,
    addresses.business.stateOrCountryDescription::VARCHAR AS stateOrCountryDescription,
    addresses.business.isForeignLocation::VARCHAR AS isForeignLocation,
    addresses.business.foreignStateTerritory::VARCHAR AS foreignStateTerritory,
    addresses.business.country::VARCHAR AS country,
    addresses.business.countryCode::VARCHAR AS countryCode,
    now() AS ingested_at  
FROM
    read_json_auto(
        CONCAT(getvariable('submissions_path'),'*.json'),
        filename = True
    ) AS t
WHERE
    EXISTS( SELECT 1 FROM filter_list f WHERE CAST(t.cik AS INTEGER) = f.cik )
    AND t.filename NOT LIKE '%-submissions-%.json' 
    ;

DROP TABLE IF EXISTS filter_list;
CREATE OR REPLACE TABLE rawDataFilesLoaded AS
SELECT cik, lastModified FROM raw_data;
CHECKPOINT;

