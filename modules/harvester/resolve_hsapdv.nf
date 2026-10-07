/**
 * Resolve HsapDv Module (step 0c)
 *
 * Reads the HsapDv (human development stage) ontology and keeps the stages that
 * start at or after the minimum age. The age is kept in the file as "min_age".
 *
 * Input:
 * ------
 * @param min_age: minimum age in years, for example 15
 *
 * Output:
 * -------
 * @emit json: hsapdv_adult_{min_age}.json
 * @emit csv:  hsapdv_adult_{min_age}.csv
 * @emit log:  hsapdv_adult_{min_age}.log
 */
process resolve_hsapdv_process {
    tag "resolve_hsapdv_${min_age}"
    publishDir "${params.run_name}", mode: params.publish_mode

    input:
    val min_age

    output:
    path "hsapdv_adult_*.json", emit: json
    path "hsapdv_adult_*.csv",  emit: csv
    path "hsapdv_adult_*.log",  emit: log

    script:
    """
    cellxgene-harvester --run-dir . resolve-hsapdv --min-age ${min_age} --output-prefix hsapdv_adult_${min_age} < /dev/null
    """

    stub:
    """
    echo '{"queries": ["min_age=${min_age}"], "min_age": ${min_age}, "root_terms": [{"obo_id": "HsapDv:0000000", "label": "stage"}], "obo_ids": ["HsapDv:0000000"], "terms": [], "total": 1}' > hsapdv_adult_${min_age}.json
    printf 'obo_id,label,start_years_post_birth\\nHsapDv:0000000,stage,${min_age}\\n' > hsapdv_adult_${min_age}.csv
    touch hsapdv_adult_${min_age}.log
    """
}
