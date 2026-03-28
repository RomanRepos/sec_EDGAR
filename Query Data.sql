SELECT cik, json_keys(facts) FROM raw_data;

SELECT DISTINCT json_keys(facts) FROM raw_data;


