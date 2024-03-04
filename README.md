# mon-deployment

## Description:
Based on the result of "kubectl top pod" (CPU &amp; Memory), it calculates the average and records the average and maximum consumption recorded in each of the pods of the deployments.app of a namespace of a context.

monitor.sh use three simple question, Context, Namespace and Minutes, and start. Then show the temporal file and his cycle number.

Example:
```txt
Working in namespace "kube-system" of "cluster-dev" by "1440" minutes
tmp-file: /tmp/tmp.pynyvz7c7p
ciclo: 94 de 6863
waiting...
```

view-tmp.sh allows you to view the snapshot of the temporal file, with ```watch``` you can view the changes.

## Requires:
- bash
- column
- kubectl
- kubectx

## Install:

```bash
git clone git@github.com:RAcl/mon-deployment.git
```

## Use:
### monitor.sh
```bash
cd mon-deployment
./monitor.sh
```

Or

```bash
mon-deployment/monitor.sh
```

### view-tmp.sh
```bash
cd mon-deployment
./view-tmp.sh tmp-file
```

Or

```bash
mon-deployment/view-tmp.sh tmp-file
```

Example:
```bash
watch -n 5 ./view-tmp.sh /tmp/tmp.pynyvz7c7p
```

## Disclaimer
The scripts were built in Debian and are not fully tested.

While they should not do any harm, execution is at your own risk.

### Warning:
This script monitor.sh change the context to the script's work context every cycle (kubectl top pod -n $namespace), then return to the initial context.

I do not recommend using other contexts while the script is running.
