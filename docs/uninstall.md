# Uninstall

```bash
helm -n asp uninstall asp
kubectl delete namespace asp
```

This removes the ASP workloads only. Your PostgreSQL and Redis are external and are left
untouched - the schema and data ASP wrote remain in your database until you drop them.
