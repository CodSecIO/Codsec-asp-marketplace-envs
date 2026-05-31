# apptest (TODO)

`mpdev verify` requires a tester that runs after install and exits 0 on success.
The tester is a Pod annotated `marketplace.cloud.google.com/verification: test`,
typically packaged as a small chart under `apptest/deployer/`.

Planned smoke test: curl the backend `/healthz` and the secops-mcp `/health`
in-cluster, and confirm the frontend Service responds, then exit 0.

This is not implemented yet - it is required before submission.
