# Support Utilities for HpcFlow's/MatFlow's Github Actions
Miscellaneous support pieces for Github Actions.

## Actions

Simple components that capture common patterns.
* [`compare`](compare/) &mdash; Compare the output of a program against a string.
* [`configure-git`](configure-git/) &mdash; Configures [git](https://git-scm.com/) for robotic commits.
* [`init-cache`](init-cache/) &mdash; Set up dependency caching using a standard pattern. 
* [`setup-poetry`](setup-poetry/) &mdash; Set up [poetry](https://python-poetry.org/) for use.

## Component Workflows

Implementations of templated workflows, separating the templating from what the workflows do.
* [`benchmark-impl`](.github/workflows/benchmark-impl.yml) &mdash; Benchmark workflow performance.
  * No special permissions required.
* [`build-exes-impl`](.github/workflows/build-exes-impl.yml) &mdash; Build executables.
  * No special permissions required.
* [`doc-build-impl`](.github/workflows/doc-build-impl.yml) &mdash; Build documentation *for one version*.
  * No special permissions required _if publication disabled_ (default).
  * If publication enabled, requires: `pages: write`, `id-token: write`  
    This is to allow publication of a site to be done.
* [`release-impl`](.github/workflows/release-impl.yml) &mdash; Create a release.
  * Permissions: `contents: write`, `id-token: write`  
    This is to allow commits to be made to make release tags, etc. (Note that appropriate secrets must also be supplied for some operations.)
* [`test-impl`](.github/workflows/test-impl.yml) &mdash; Run the test suite.
  * Permissions: `contents: write`, `id-token: write`  
    This is to allow the "commit hook" that runs [black](https://github.com/psf/black) to write its changes.
* [`test-pre-python-impl`](.github/workflows/test-pre-python-impl.yml) &mdash; Run the test suite with a pre-release version of Python.
  * No special permissions required.

These workflows use the actions listed above.

## Support Scripts/Files

Files used by other parts of this repository, principally for testing purposes.
* [`problem-matchers/sphinx.json`](problem-matchers/sphinx.json) &mdash; Originally evolved from something in Python's own code, used to pick errors out of [Sphinx](https://www.sphinx-doc.org/en/master/)'s (voluminous) output and highlight it. Used by `doc-build-impl`.
* [`scripts/get_invoc_cmd.py`](scripts/get_invoc_cmd.py) &mdash; Test harness: non-interactive invocation.
* [`scripts/get_invoc_cmd_interactive.py`](scripts/get_invoc_cmd_interactive.py) &mdash; Test harness: interactive invocation (not Windows).
* [`scripts/test_direct_sub_python_script.py`](scripts/test_direct_sub_python_script.py) &mdash; Test harness: call as library.
* [`scripts/test_direct_sub_jupyter_notebook.ipynb`](scripts/test_direct_sub_jupyter_notebook.ipynb) &mdash; Test harness: call from [ipython](https://ipython.org/).
