SET
    VARIABLE facts_path = '{{facts_path_param}}';



SET
    VARIABLE submissions_path = '{{submissions_path_param}}';

SET
    VARIABLE standard_line_items_path = '{{standard_line_items_path_param}}';

SET
    VARIABLE fact_path_no_json = REPLACE('{{facts_path_param}}', '*.json', '');


CREATE OR REPLACE TABLE standardLineItems AS
SELECT
    row_number() OVER () AS id,
    standard_label,
    statement :: VARCHAR [] AS statement,
    semantic_description,
    TRUE AS isActive
FROM
    read_json_auto(
        getvariable('standard_line_items_path')
    );


CHECKPOINT;

