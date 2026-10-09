/**
 * Resolve Assay Module (step 0d, optional)
 *
 * Resolves the assays (techniques) you WANT, each by its EFO label or EFO id.
 * Each assay is resolved on its own: there is no root term and no descendants.
 * The file is an allow-list: only the cells whose assay ontology id is in it are
 * counted on the filtered side, so every other assay (for example every spatial
 * technique) is left out by not being in the file.
 *
 * A label must match one EFO term exactly, or be an EFO id such as EFO:0009922.
 * The step never asks a question. A label that does not resolve is listed under
 * "unresolved" in the file and in the log, and is skipped. The step stops only
 * when no assay resolves at all. Read the "unresolved" list: a label that did not
 * resolve is left out of the counts too.
 *
 * The file is named for the set of assays, by the assay_name parameter (default
 * 'published'), not for its first label: a set of 12 assays would otherwise be
 * named after one of them.
 *
 * Input:
 * ------
 * @param queries: list of assay labels or EFO ids, for example
 *                 ['10x 3\' v3', 'Smart-seq2', 'EFO:0009900']
 *
 * Output:
 * -------
 * @emit json: assay_{assay_name}.json (default assay_published.json)
 * @emit csv:  assay_{assay_name}.csv
 * @emit log:  assay_{assay_name}.log
 */
process resolve_assay_process {
    tag "resolve_assay_${params.assay_name}"
    publishDir "${params.run_name}", mode: params.publish_mode

    input:
    val queries

    output:
    path "assay_*.json", emit: json
    path "assay_*.csv",  emit: csv
    path "assay_*.log",  emit: log

    script:
    def slug = params.assay_name.toString().toLowerCase().replaceAll(/[^a-z0-9]+/, '_').replaceAll(/^_+|_+$/, '')
    def args = queries.collect { q -> "'" + q.toString().replace("'", "'\\''") + "'" }.join(' ')
    """
    cellxgene-harvester --run-dir . resolve-assay ${args} --output-prefix assay_${slug} < /dev/null \
        || { echo "ERROR: no --assay value resolved. Each must be an exact EFO label or an EFO id." >&2; exit 1; }
    """

    stub:
    def slug = params.assay_name.toString().toLowerCase().replaceAll(/[^a-z0-9]+/, '_').replaceAll(/^_+|_+$/, '')
    """
    cat > assay_${slug}.json <<'STUB_END'
    {"queries": ["stub"], "assays": [{"query": "stub", "obo_id": "EFO:0000000", "label": "stub"}], "unresolved": [], "obo_ids": ["EFO:0000000"], "total": 1}
    STUB_END
    printf 'obo_id,label,query\\nEFO:0000000,stub,stub\\n' > assay_${slug}.csv
    touch assay_${slug}.log
    """
}
