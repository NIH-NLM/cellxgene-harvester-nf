/**
 * Resolve UBERON Module (step 0a)
 *
 * Resolves one organ (an UBERON label or id) and all its descendants through the
 * OLS4 web service, and writes the term file that the later steps read.
 *
 * The label must match one UBERON term exactly, or be an UBERON id such as
 * UBERON:0002113. The step never asks a question: if the label does not match
 * exactly, the step stops with an error, so no organ is chosen for you.
 *
 * relations are exact relation labels, for example 'contributes to morphology of':
 * the terms that have that relation to the organ are added, with their descendants.
 * The nose is not below the respiratory system but contributes to its morphology,
 * so this adds it. The organ stays the one root term.
 *
 * Input:
 * ------
 * @param query:     UBERON label or id, for example 'kidney'
 * @param relations: list of exact relation labels to add, or an empty list for none
 *
 * Output:
 * -------
 * @emit json: uberon_{label}.json (queries, root_terms, obo_ids, terms, total; relations and related_terms when relations are given)
 * @emit csv:  uberon_{label}.csv
 * @emit log:  uberon_{label}.log
 */
process resolve_uberon_process {
    tag "resolve_uberon_${query}"
    publishDir "${params.run_name}", mode: params.publish_mode

    input:
    val query
    val relations

    output:
    path "uberon_*.json", emit: json
    path "uberon_*.csv",  emit: csv
    path "uberon_*.log",  emit: log

    script:
    def slug = query.toString().toLowerCase().replaceAll(/[^a-z0-9]+/, '_').replaceAll(/^_+|_+$/, '')
    def relation_flags = relations.collect { r -> "--also-relation '" + r.toString().replace("'", "'\\''") + "'" }.join(' ')
    """
    cellxgene-harvester --run-dir . resolve-uberon '${query}' ${relation_flags} --output-prefix uberon_${slug} < /dev/null \
        || { echo "ERROR: '${query}' is not an exact UBERON label or id. Give the exact label or the UBERON id (--organ)." >&2; exit 1; }
    """

    stub:
    def slug = query.toString().toLowerCase().replaceAll(/[^a-z0-9]+/, '_').replaceAll(/^_+|_+$/, '')
    """
    echo '{"queries": ["${query}"], "root_terms": [{"obo_id": "UBERON:0000000", "label": "${query}", "level": "root"}], "obo_ids": ["UBERON:0000000"], "terms": [], "total": 1}' > uberon_${slug}.json
    printf 'obo_id,label,level\\nUBERON:0000000,${query},root\\n' > uberon_${slug}.csv
    touch uberon_${slug}.log
    """
}
