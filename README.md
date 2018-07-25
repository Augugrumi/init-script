# Repo for installing K8s, GlusterFS and Helm
# Script to install all the software
If you want to deploy k8s, GlusterFS and helm on a set of machine with a certain IP (e.g. 192.168.29.28, 192.168.29.24, 192.168.29.19), supposing that all the machine, except master, have a disk on `/dev/vdb` formatted for Gluster, run the command:
```bash
$ bash <(curl -s https://raw.githubusercontent.com/Augugrumi/init-script/centos/installAll.sh) \
   -a 192.168.29.28 -a 192.168.29.24 -a 192.168.29.19 -a 192.168.29.12 -b centos -p 10243
```
where:
 + `-a` option is used to specify IP addresses (the first is taken as master node)
 + `-b` is used to specify the branch or the commit of the scripts that you want to refer to (default is `centos`)
 + `-p` the port for the ssh to Openstack
 
 To deploy k8s at least 2 nodes are needed,k for GlusterFS 3 is the minimum.
 
## Warning
At that time these scripts contains hard coded name of public keys and connection to Openstack
