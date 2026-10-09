/**
 * Publish Module (step 8)
 *
 * Copies the final files and the resolve files of the run to a NEW branch of the
 * GitHub repository (default NIH-NLM/nlm-ckn), for you to inspect and merge by
 * hand. Nothing is pushed to main. The per-dataset working files are not published.
 *
 * Branch:  {YYYY-mon-DD}-{HHmm}-{organ}-cellxgene-harvester-nf
 *          for example 2026-oct-07-1415-kidney-cellxgene-harvester-nf
 *
 * Folders (publish_env = prod, the default):
 *
 * - data/prod/{organ}/cellxgene-harvester-nf/ holds the final JSON and CSV and the
 *   organ's uberon JSON and CSV, all at the same level (no subfolder).
 * - data/prod/ontology_lookup_server/ holds the disease, hsapdv and assay JSON and CSV
 *   files shared by every organ.
 * - The filtered h5ad files go to the public S3 bucket, not to GitHub.
 *
 * Folders (publish_env = test): the same under data/test/, and the filtered h5ad
 * files go to data/test/{organ}/filtered-h5ad/.
 *
 * The step is skipped, with a warning, when github_token is not given.
 *
 * Input:
 * ------
 * @param organ_files:  the final JSON and CSV and the organ's resolve files
 * @param shared_files: the disease, hsapdv and assay resolve files (JSON and CSV)
 * @param h5ad:         the filtered h5ad files (copied only when publish_env is test)
 * @param branch:       name of the branch to create
 * @param organ:        organ slug, for example 'kidney'
 *
 * Output:
 * -------
 * @emit report: publish_report.txt (branch and folders)
 */
process publish_github_process {
    tag "publish_${organ}"
    maxForks 1
    // no errorStrategy 'ignore': a failed publish must show its error

    input:
    path organ_files,  stageAs: 'organ/*'
    path shared_files, stageAs: 'shared/*'
    path h5ad,         stageAs: 'h5ad/*'
    val branch
    val organ

    output:
    path "publish_report.txt", emit: report

    script:
    def repo      = params.publish_repo
    def json_dir  = params.publish_dest_dir ?: "data/${params.publish_env}/${organ}/cellxgene-harvester-nf"
    def shared_dir = params.publish_shared_dir ?: "data/${params.publish_env}/ontology_lookup_server"
    def h5ad_dir  = "data/test/${organ}/filtered-h5ad"
    def copy_h5ad = params.publish_env == 'test'
    def repo_url  = repo.contains('://') ? repo : "https://\${GITHUB_TOKEN}@github.com/${repo}.git"   // a full address is for tests
    """
    export GITHUB_TOKEN="${params.github_token}"
    case "\${GITHUB_TOKEN}" in
        ""|true|false|null)
            echo "ERROR: github_token is empty. In GitHub Actions the secret NLM_CKN_TOKEN is not set (Settings > Secrets and variables > Actions)." >&2
            exit 1 ;;
    esac

    git clone --depth 1 ${repo_url} publish-repo 2>&1 | sed "s/\${GITHUB_TOKEN}/***/g" ; test -d publish-repo/.git || { echo "ERROR: cannot clone ${repo}: check that the token can read it" >&2; exit 1; }
    cd publish-repo
    git config user.email "cellxgene-harvester-nf@noreply.github.com"
    git config user.name  "cellxgene-harvester-nf"
    git checkout -b ${branch}

    mkdir -p "${json_dir}" "${shared_dir}"
    for f in ../organ/*;   do [ "\$(basename "\$f")" = NO_FILE ] || cp -L "\$f" "${json_dir}/"; done
    for f in ../shared/*;  do [ "\$(basename "\$f")" = NO_FILE ] || cp -L "\$f" "${shared_dir}/"; done
    ${copy_h5ad ? """
    mkdir -p "${h5ad_dir}"
    cp -L ../h5ad/*.h5ad "${h5ad_dir}/" 2>/dev/null || true""" : ''}

    git add data/
    git commit -m "cellxgene-harvester-nf: ${organ} ${params.publish_env} results (${branch})"
    git push origin ${branch} 2>&1 | sed "s/\${GITHUB_TOKEN}/***/g"; test \${PIPESTATUS[0]} -eq 0 || { echo "ERROR: cannot push ${branch} to ${repo}: the token needs write access (contents: write)" >&2; exit 1; }

    echo "branch : ${branch}"   >  ../publish_report.txt
    echo "repo   : ${repo}"     >> ../publish_report.txt
    echo "folder : ${json_dir}" >> ../publish_report.txt
    echo "shared : ${shared_dir}" >> ../publish_report.txt
    """

    stub:
    """
    echo "stub: would publish ${organ} to ${branch}" > publish_report.txt
    """
}
