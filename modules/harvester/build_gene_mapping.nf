/**
 * Build Gene Mapping Module (step 5b)
 *
 * Builds the gene id to gene name table of the GENCODE release that the CellxGene
 * datasets use, with its provenance file. The release is the one of the newest
 * CellxGene schema (v48 today) unless --gencode_release is given.
 *
 * If the table of this release is already in data_dir/gencode and is intact (its provenance
 * file names the release and holds the SHA-256 of the table), it is used and nothing is
 * downloaded. Otherwise the GENCODE annotation is downloaded, its MD5 is checked against
 * the one GENCODE publishes, and the table is built.
 *
 * The table has no date inside it, so the same release always gives the same bytes.
 * The provenance file holds the source, the checksums and the date.
 *
 * Input:
 * ------
 * @param gtf: a local GENCODE annotation file to use instead of downloading it (for tests), or assets/NO_FILE
 * @param existing: the gencode folder of data_dir, or assets/NO_FILE
 *
 * Output:
 * -------
 * @emit csv:        gene_mapping_gencode_v<N>.csv
 * @emit provenance: gene_mapping_gencode_v<N>.provenance.json
 */
process build_gene_mapping_process {
    tag "build_gene_mapping"
    publishDir "${params.run_name}/gene_mapping", mode: params.publish_mode, saveAs: { fn -> file(fn).name }

    input:
    path gtf
    path existing, stageAs: 'existing'

    output:
    path "gene_mapping/gene_mapping_gencode_v*.csv",              emit: csv
    path "gene_mapping/gene_mapping_gencode_v*.provenance.json",  emit: provenance

    script:
    def release_flag = params.gencode_release ? "--gencode-release ${params.gencode_release}" : ''
    def gtf_flag     = gtf.name != 'NO_FILE' ? "--gtf ${gtf}" : ''
    """
    # the table that is already there is not made again
    mkdir -p gene_mapping
    cp -L existing/gene_mapping_gencode_v*.csv existing/gene_mapping_gencode_v*.provenance.json gene_mapping/ 2>/dev/null || true
    cellxgene-harvester --run-dir . build-gene-mapping --output-dir gene_mapping ${release_flag} ${gtf_flag}
    """

    stub:
    def release = params.gencode_release ?: 48
    """
    mkdir gene_mapping
    printf 'ensembl_gene_id,gene_name,gene_type,hgnc_id,has_symbol,gencode_release\\nENSG00000000001,GENEA,protein_coding,HGNC:1,True,${release}\\n' > gene_mapping/gene_mapping_gencode_v${release}.csv
    echo '{"gencode_release": ${release}, "stub": true}' > gene_mapping/gene_mapping_gencode_v${release}.provenance.json
    """
}
