import cli

# Scaffold smoke test: the package imports and exposes its version. Replaced by
# the real surface tests as the first-slice issues land.
@test
def _reports_the_scaffold_version():
    assert cli.version() == "0.1.0"
