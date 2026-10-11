/**
 * Fetch Collections Module (step 1)
 *
 * Fetches every public collection from the CellxGene curation API.
 *
 * Output:
 * -------
 * @emit json: collections_metadata.json
 */
process fetch_collections_process {
    tag "fetch_collections"
    publishDir "${params.run_name}", mode: params.publish_mode

    input:
    path existing, stageAs: 'existing'

    output:
    path "collections_metadata.json",      emit: json
    path "api_snapshot.provenance.json",   emit: provenance

    script:
    """
    # the files made before: if the API has not changed, step 1 keeps their provenance file
    cp -L existing/collections_metadata.json existing/api_snapshot.provenance.json . 2>/dev/null || true
    cellxgene-harvester --run-dir . fetch-collections
    """

    stub:
    """
    echo '[]' > collections_metadata.json
    echo '{"kind": "api", "date": "2000-01-01", "files": {}}' > api_snapshot.provenance.json
    """
}
