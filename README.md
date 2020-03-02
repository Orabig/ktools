# ktools

Some bash tools for Kubernetes users

## Usage

* `kctx` shows existing contexts
* `kctx [ CONTEXT ]` : selects given context
* `kns` : shows existing namespaces
* `kns [ NAMESPACE ]` : selects given namespaces

eg.

```

```

Some aliases are also defined :

```
$ k      # Alias for 'kubectl'
$ ka     # Alias for 'kubectl apply'
$ kd     # Alias for 'kubectl delete'
$ kdf    # Alias for 'kubectl delete --grace-period=0 --force'
$ kgp    # Alias for 'kubectl get pods --watch'
```