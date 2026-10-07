/**
 * Resolve Disease Module (step 0b)
 *
 * Resolves one disease or phenotype (a PATO or MONDO label or id) and all its
 * descendants through the OLS4 web service.
 *
 * The label must match one term exactly, or be an id such as PATO:0000461. The
 * step never asks a question: if the label does not match exactly, the step
 * stops with an error.
 *
 * Input:
 * ------
 * @param query: disease label or id, for example 'normal'
 *
 * Output:
 * -------
 * @emit json: disease_{label}.json
 * @emit csv:  disease_{label}.csv
 * @emit log:  disease_{label}.log
 */
process resolve_disease_process {
    tag "resolve_disease_${query}"
    publishDir "${params.run_name}", mode: params.publish_mode

    input:
    val query

    output:
    path "disease_*.json", emit: json
    path "disease_*.csv",  emit: csv
    path "disease_*.log",  emit: log

    script:
    def slug = query.toString().toLowerCase().replaceAll(/[^a-z0-9]+/, '_').replaceAll(/^_+|_+$/, '')
    """
    cellxgene-harvester --run-dir . resolve-disease '${query}' --output-prefix disease_${slug} < /dev/null \
        || { echo "ERROR: '${query}' is not an exact disease label or id. Give the exact label or the id (--disease)." >&2; exit 1; }
    """

    stub:
    def slug = query.toString().toLowerCase().replaceAll(/[^a-z0-9]+/, '_').replaceAll(/^_+|_+$/, '')
    """
    echo '{"queries": ["${query}"], "root_terms": [{"obo_id": "PATO:0000000", "label": "${query}", "level": "root"}], "obo_ids": ["PATO:0000000"], "terms": [], "total": 1}' > disease_${slug}.json
    printf 'obo_id,label,level\\nPATO:0000000,${query},root\\n' > disease_${slug}.csv
    touch disease_${slug}.log
    """
}
