# Script to install GlusterFS
If you want to deploy GlusterFS set of machine with a certain IP (e.g. 192.168.29.28, 192.168.29.24, 192.168.29.19, 192.168.29.12), supposing that all the machine, except master, have a disk on `/dev/vdb` formatted, run the command:
```bash
$ bash <(curl -s https://raw.githubusercontent.com/Augugrumi/init-script/centos/glusterfs/installer.sh) \
   -a 192.168.29.28 -a 192.168.29.24 -a 192.168.29.19 -a 192.168.29.12 -b centos
```
where:
 + `-a` option is used to specify IP addresses (the first is taken as master node)
 + `-b` is used to specify the branch or the commit of the scripts that you want to refer to (default is `centos`)
 
 To deploy GlusterFS at least 3 node with a disk are needed (and a working installation of K8s).
 
## Warning
 + At that time these scripts contains hard coded name of public keys and connection to Openstack
 + This script have to be run on the machine on Openstack that has a floating IP
