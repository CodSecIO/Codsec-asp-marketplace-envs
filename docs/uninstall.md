# Uninstall

```bash
helm -n asp uninstall asp
kubectl delete namespace asp
```

> **Warning:** deleting the namespace removes the bundled PostgreSQL PersistentVolumeClaim
> and all data in it. Back up anything you need first.
