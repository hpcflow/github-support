# Support scripts

The Python scripts support the `test-impl.yml` workflow.

Run `bash scripts/test-release-recovery.sh` to test stable release recovery with
temporary local Git repositories and mocked Poetry/API calls. No credentials,
network requests, or publication are needed.

Run `bash scripts/test-release-develop-sync.sh` to test the stable release sync of
the pre-release branch against temporary local Git remotes.
