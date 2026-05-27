# Uninstall

```bash
./scripts/uninstall.sh
```

Or manually:

```bash
helm -n asp uninstall asp-frontend
helm -n asp uninstall asp-backend
kubectl delete namespace asp

cd terraform
terraform destroy
```

> **Warning:** `terraform destroy` deletes the CloudSQL instance and all data. Take a backup first if you need to retain anything.
