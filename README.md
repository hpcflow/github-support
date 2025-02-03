# Support Utilities for HpcFlow's/MatFlow's Github Actions
Miscellaneous support pieces for Github Actions.

* Actions

  Simple components that capture common patterns.
  * `compare` &mdash; Compare the output of a program against a string.
  * `configure-git` &mdash; Configures git for robotic commits.
  * `init-cache` &mdash; Set up dependency caching using a standard pattern. 
  * `setup-poetry` &mdash; Set up poetry for use.
* Component Workflows

  Implementations of templated workflows, separating the templating from what the workflows do.
  * `benchmark-impl` &mdash; Benchmark workflow performance.
  * `build-exes-impl` &mdash; Build executables.
  * `doc-build-impl` &mdash; Build documentation *for one version*.
  * `release-impl` &mdash; Create a release.
  * `test-impl` &mdash; Run the test suite.
  * `test-pre-python-impl` &mdash; Run the test suite with a pre-release version of Python.
* Support Scripts/Files

  Files used by other parts of this repository, principally for testing purposes.
  * `problem-matchers/sphinx.json`
  * `scripts/get_invoc_cmd.py`
  * `scripts/get_invoc_cmd_interactive.py`
  * `scripts/test_direct_sub_python_script.py`
  * `scripts/test_direct_sub_jupyter_notebook.ipynb`
