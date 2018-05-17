#! /bin/bash

#apt-get update
#apt-get install qemu-kvm libvirt-bin virtinst bridge-utils genisoimage

source config

bash user-data.sh

# config-drives/vm1-config/meta-data
# config-drives/vm2-config/meta-data
bash meta-data.sh

# Networks !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
mkdir networks


VM1_EXTERNAL_MAC=52:54:00:`(date; cat /proc/interrupts) | md5sum | sed -r 's/^(.{6}).*$/\1/; s/([0-9a-f]{2})/\1:/g; s/:$//;'`
VM1_INTERNAL_MAC=52:54:00:`(date; cat /proc/interrupts) | md5sum | sed -r 's/^(.{6}).*$/\1/; s/([0-9a-f]{2})/\1:/g; s/:$//;'`
VM1_MANAGEMENT_MAC=52:54:00:`(date; cat /proc/interrupts) | md5sum | sed -r 's/^(.{6}).*$/\1/; s/([0-9a-f]{2})/\1:/g; s/:$//;'`
EXTERNAL_NET_MAC=52:54:00:`(date; cat /proc/interrupts) | md5sum | sed -r 's/^(.{6}).*$/\1/; s/([0-9a-f]{2})/\1:/g; s/:$//;'`
VM2_INTERNAL_MAC=52:54:00:`(date; cat /proc/interrupts) | md5sum | sed -r 's/^(.{6}).*$/\1/; s/([0-9a-f]{2})/\1:/g; s/:$//;'`
VM2_MANAGEMENT_MAC=52:54:00:`(date; cat /proc/interrupts) | md5sum | sed -r 's/^(.{6}).*$/\1/; s/([0-9a-f]{2})/\1:/g; s/:$//;'`

extnet="<network>\n
  <name>$EXTERNAL_NET_NAME</name>\n
  <uuid>768affe2-055e-4d47-be93-55a14be3359e</uuid>\n
  <forward mode='nat'>\n
    <nat>\n
      <port start='1024' end='65535'/>\n
    </nat>\n
  </forward>\n
  <bridge name='virbr1' stp='on' delay='0'/>\n
  <mac address='$EXTERNAL_NET_MAC'/>\n
  <ip address='$EXTERNAL_NET_HOST_IP' netmask='$EXTERNAL_NET_MASK'>\n
    <dhcp>\n
      <host mac='$VM1_EXTERNAL_MAC' ip='$VM1_EXTERNAL_IP'/>\n	
    </dhcp>\n
  </ip>\n
</network>"

echo -e $extnet > networks/external.xml


intnet="<network>\n
  <name>$INTERNAL_NET_NAME</name>\n
  <uuid>768affe2-055e-4d47-be93-55a14be8859e</uuid>\n
</network>"

echo -e $intnet > networks/internal.xml


MANAGEMENT_NET_MAC=52:54:00:`(date; cat /proc/interrupts) | md5sum | sed -r 's/^(.{6}).*$/\1/; s/([0-9a-f]{2})/\1:/g; s/:$//;'`

mgmnet="<network>\n
  <name>$MANAGEMENT_NET_NAME</name>\n
  <uuid>768affe2-055e-4d47-be93-55a14be9959e</uuid>\n
  <bridge name='virbr3' stp='on' delay='0'/>\n
  <ip address='$MANAGEMENT_HOST_IP' netmask='$MANAGEMENT_NET_MASK'>\n
  </ip>
  <mac address='$MANAGEMENT_NET_MAC'/>\n
</network>"

echo -e $mgmnet > networks/management.xml

# Networks create

virsh net-define networks/external.xml
virsh net-define networks/internal.xml
virsh net-define networks/management.xml

# Network start

virsh net-start external
virsh net-start internal
virsh net-start management


# Download image for vm.!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
wget $VM_BASE_IMAGE

# Create first vm (vm1)

mkisofs -o $VM1_CONFIG_ISO -V cidata -r -J --quiet config-drives/vm1-config
cp $(basename $VM_BASE_IMAGE) $VM1_HDD
virt-install \
--connect qemu:///system \
--name $VM1_NAME \
--ram $VM1_MB_RAM --vcpus=$VM1_NUM_CPU --$VM_TYPE \
--os-type=linux --os-variant=ubuntu16.04 \
--disk path=$VM1_HDD,format=qcow2,bus=virtio,cache=none \
--disk path=$VM1_CONFIG_ISO,device=cdrom \
--network network=$EXTERNAL_NET_NAME,mac=$VM1_EXTERNAL_MAC \
--network network=$INTERNAL_NET_NAME,mac=$VM1_INTERNAL_MAC \
--network network=$MANAGEMENT_NET_NAME,mac=$VM1_MANAGEMENT_MAC \
--graphics vnc,port=-1 \
--noautoconsole --quiet --virt-type $VM_VIRT_TYPE --import



# Create second vm (vm2)

mkisofs -o $VM2_CONFIG_ISO -V cidata -r -J --quiet config-drives/vm2-config
cp $(basename $VM_BASE_IMAGE) $VM2_HDD
virt-install \
--connect qemu:///system \
--name $VM2_NAME \
--ram $VM2_MB_RAM --vcpus=$VM2_NUM_CPU --$VM_TYPE \
--os-type=linux --os-variant=ubuntu16.04 \
--disk path=$VM2_HDD,format=qcow2,bus=virtio,cache=none \
--disk path=$VM2_CONFIG_ISO,device=cdrom \
--network network=$INTERNAL_NET_NAME,mac=$VM2_INTERNAL_MAC \
--network network=$MANAGEMENT_NET_NAME,mac=$VM2_MANAGEMENT_MAC \
--graphics vnc,port=-1 \
--noautoconsole --quiet --virt-type $VM_VIRT_TYPE --import

