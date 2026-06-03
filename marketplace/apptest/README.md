# apptest

Tester for `mpdev verify`. After install, Marketplace runs the Pod in
`deployer/asp/templates/tester.yaml` (annotated
`marketplace.cloud.google.com/verification: test`) and reads its exit code.

The tester smoke-checks the deployed services in-cluster:
- backend `GET /api/health`
- frontend `GET /`

It exits non-zero on the first failure. Extend it as the app gains real
readiness signals.
