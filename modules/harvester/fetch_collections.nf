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

    output:
    path "collections_metadata.json", emit: json

    script:
    """
    cellxgene-harvester --run-dir . fetch-collections
    """

    stub:
    """
    echo '[]' > collections_metadata.json
    """
}
