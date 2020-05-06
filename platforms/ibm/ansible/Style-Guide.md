# Style Guide

## k8s modules

The k8s module has a few different ways to specify things. ie: the API Version can be a module argument, or a sub element of the `definition`. We also want the standardize on specifying all the needed arguments.

When using the k8s module, follow this template for order of arguments.

```yaml
  k8s:
    state: present
    definition:
      apiVersion: v1
      kind: Pod
      metadata:
        name: foo
        namespace: bla
      spec:
        <spec stuff>
```

When using the_info k8s module, follow this template for order of arguments.

```yaml
  k8s_info:
    api_version: v1
    kind: Pod
    name: foo
    namespace: bla
```
