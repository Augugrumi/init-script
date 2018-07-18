# Scripts to install Kubernet and setup a cluster

If you want to deploy k8s on a set of machine with a certain IP (e.g. 192.168.29.28, 192.168.29.24, 192.168.29.19) run the command:
```bash
$ bash <(curl -s https://raw.githubusercontent.com/Augugrumi/init-script/master/kubernetes/on_openstack_cli.sh) \
   -a 192.168.29.28 -a 192.168.29.24 -a 192.168.29.19 -b master
```
where:
 + `-a` option is used to specify IP addresses (the first is taken as master node)
 + `-b` is used to specify the branch or the commit of the scripts that you want to refer to (default is `master`)
 + `-p` the port for the ssh to Openstack
 
 To deploy k8s at least 2 nodes are needed
 
## Warning
At that time these scripts contains hard coded name of public keys and connection to Openstack
