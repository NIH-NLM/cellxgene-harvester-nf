/**
 * Resolve Assay Module (step 0d, optional)
 *
 * Resolves one or more assay (technique) terms in EFO, with all their
 * descendants. The file is a NEGATIVE selection: the cells whose assay ontology
 * id is in it are left out of the filtered counts (for example spatial
 * techniques). Each query is a root term and must match one EFO term exactly,
 * or be an EFO id such as EFO:0008994. The step never asks a question.
 *
 * Input:
 * ------
 * @param queries: list of assay labels or EFO ids, for example
 *                 ['spatial transcriptomics', 'MERFISH']
 *
 * Output:
 * -------
 * @emit json: assay_{first label}.json
 * @emit csv:  assay_{first label}.csv
 * @emit log:  assay_{first label}.log
 */
process resolve_assay_process {
    tag "resolve_assay_${queries[0]}"
    publishDir "${params.run_name}", mode: params.publish_mode

    input:
    val queries

    output:
    path "assay_*.json", emit: json
    path "assay_*.csv",  emit: csv
    path "assay_*.log",  emit: log

    script:
    def slug = queries[0].toString().toLowerCase().replaceAll(/[^a-z0-9]+/, '_').replaceAll(/^_+|_+$/, '')
    def args = queries.collect { q -> "'" + q.toString().replace("'", "'\\''") + "'" }.join(' ')
    """
    cellxgene-harvester --run-dir . resolve-assay ${args} --output-prefix assay_${slug} < /dev/null \
        || { echo "ERROR: every --exclude_assay value must be an exact EFO label or an EFO id." >&2; exit 1; }
    """

    stub:
    def slug = queries[0].toString().toLowerCase().replaceAll(/[^a-z0-9]+/, '_').replaceAll(/^_+|_+$/, '')
    """
    echo '{"queries": ["${queries[0]}"], "root_terms": [{"obo_id": "EFO:0000000", "label": "${queries[0]}", "level": "root"}], "obo_ids": ["EFO:0000000"], "terms": [], "total": 1}' > assay_${slug}.json
    printf 'obo_id,label,level\\nEFO:0000000,${queries[0]},root\\n' > assay_${slug}.csv
    touch assay_${slug}.log
    """
}
