# Script to create instances on openstack-cli
To create a set of machine on Openstack from the CLI you can run for example this command:
```bash
vmlaunch -i "k8-" -n "vibes_eth" -s "davmarkp0" -m "4" -r "ubuntu-srv-1604"
```
In that case the script will launch **4** instances, named **k8-{1,2,3,4}** on the network called **vibes_eth** using the key **davmarkp0** using the image **ubuntu-srv-1604**.
+ `-i` is the prefix of the name of the instances (that will be enumerated)
+ `-n` is the name of the network on which the instances will be deployed
+ `-s` is the key used for ssh
+ `-m` is the (max) number of instances created
+ `-r` is the image used

The flavour used is **server-medium** (4 VCPUs, 8GB RAM, 12GB disk) with a volume of **40GB** that will be **deleted** when the image will be removed.

----

## delete_and_restart.sh script
The script `delete_and_restart.sh` can be used to delete the machine (k8-{1..4}) and volumes (v{2..4}) and recreate them. Usage
```bash
bash delete_and_restart.sh file.rc
```
Where `file.rc` is the file that must be sourced to run openstack commands
