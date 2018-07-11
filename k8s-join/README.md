# Script to join an existing k8s cluster
This script assume you are on **master node**, the key to access other machines is **kp-** and the command to join the cluster is stored in a file called **joincommand** in the same folder of the script.
You can run:
```bash
$ bash k8s-join.sh -a 192.168.29.19 -a 192.168.29.30
```
where `-a` option is used to specify IP addresses
