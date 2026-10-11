/**
 * Generate Metadata Module (step 2)
 *
 * Flattens the collections into one row for each dataset (latest version).
 *
 * Input:
 * ------
 * @param collections_json: collections_metadata.json from fetch_collections
 *
 * Output:
 * -------
 * @emit csv: all_datasets.csv
 */
process generate_metadata_process {
    tag "generate_metadata"
    publishDir "${params.run_name}", mode: params.publish_mode

    input:
    path collections_json, stageAs: 'collections_metadata.json'
    path provenance_in,    stageAs: 'api_snapshot.provenance.json'
    path existing,         stageAs: 'existing'

    output:
    path "all_datasets.csv",               emit: csv
    path "api_snapshot.provenance.json",   emit: provenance

    script:
    """
    # not made again if it is already there and the API has not changed
    cp -L existing/all_datasets.csv . 2>/dev/null || true
    cellxgene-harvester --run-dir . generate-metadata
    """

    stub:
    """
    echo 'reference,dataset_id' > all_datasets.csv
    cp -L api_snapshot.provenance.json prov.tmp && mv prov.tmp api_snapshot.provenance.json
    """
}
