skipx
text
install
reboot
lang en_US.UTF-8
keyboard us
timezone --utc GMT

url	--url=http://mirror.centos.org/centos/7/os/x86_64/
repo --name=Updates --baseurl=http://mirror.centos.org/centos/7/updates/x86_64/
# epel for cloud-init
repo --name=EPEL --baseurl=http://dl.fedoraproject.org/pub/epel/6/x86_64/

firewall --disabled

selinux --enforcing

# root pw will be randomised later
rootpw password
authconfig --enableshadow --passalgo=sha512

# network on, dhcp on - all platforms expect this
network --onboot yes --device=eth0 --bootproto=dhcp


zerombr
clearpart --initlabel --all
# One partition to rule them all, no swap
part / --size=1024 --grow --fstype ext4 --asprimary

# we add serial tty for `virsh console`
bootloader --location=mbr --driveorder=vda


%packages --excludedocs --nobase
openssl
openssh-server
# cloud-init and growroot will expand the partition and filesystem to match the underlying image
cloud-init
python-jsonpatch
cloud-utils-growpart
ntp
wget
acpid
tuned
dracut-config-generic
iptables-services
#do we want EPEL?
#epel-release
-*-firmware
-NetworkManager
-b43-openfwwf
-biosdevname
-fprintd
-fprintd-pam
-gtk2
-libfprint
-mcelog
-redhat-support-tool
-system-config-*
-wireless-tools
-firewalld
-iprutils
-kbd
%end
services --enabled=network,acpid,ntpd,sshd,cloud-init,cloud-init-local,cloud-config,cloud-final,tuned --disabled=kdump,iptables,ip6tables
%post --erroronfail 
#bz912 801
# prevent udev rules from remapping nics
#echo "bogus content to prevent udev rules from remapping nics bz912801" > /etc/udev/rules.d/70-*
for i in `find /etc/udev/rules.d/ -name "*persistent*"`; do echo "no re-mapping bz912801" > $i; chattr +i $i; done

#bz 1011013
# set eth0 to recover from dhcp errors
echo PERSISTENT_DHCLIENT="1" >> /etc/sysconfig/network-scripts/ifcfg-eth0

# set virtual-guest as default profile for tuned
echo "virtual-guest" > /etc/tune-profiles/active-profile

# randomise root password
openssl rand -base64 32 | passwd --stdin root

# no zeroconf
echo NOZEROCONF=yes >> /etc/sysconfig/network

echo NETWORKING=yes >> /etc/sysconfig/network

# remove existing SSH keys - if generated - as they need to be unique
rm -rf /etc/ssh/*key*
# the MAC address will change
sed -i '/HWADDR/d' /etc/sysconfig/network-scripts/ifcfg-eth0
sed -i '/UUID/d' /etc/sysconfig/network-scripts/ifcfg-eth0 
# remove logs and temp files
yum -y clean all
rm -f /root/anaconda-ks.cfg
rm -f /root/install.log
rm -f /root/install.log.syslog
find /var/log -type f -delete
# remove the random seed, it needs to be unique and it will be autogenerated
rm -f /var/lib/random-seed 
# Kdump can use quite a bit of memory, do we want to keep it? Also  EL7 boot resolution tends to be maximum, so let's dial it down a bit
grubby --update-kernel=ALL --args="crashkernel=0@0 video=1024x768 console=ttyS0,115200n8 console=tty0 consoleblank=0"
# let's see more of what is happening
grubby --update-kernel=ALL --remove-args="quiet rhgb"



# tell the system to autorelabel? this takes some time and memory, maybe not advised
# touch /.autorelabel

# remove some packages
# this is installed by default but we don't need it in virt
echo "Removing linux-firmware package."
yum -C -y remove linux-firmware

# Remove firewalld; was supposed to be optional in F18+, but is required to
# be present for install/image building.
echo "Removing firewalld."
yum -C -y remove firewalld --setopt="clean_requirements_on_remove=1"

# Another one needed at install time but not after that, and it pulls
# in some unneeded deps (like, newt and slang)
echo "Removing authconfig."
yum -C -y remove authconfig --setopt="clean_requirements_on_remove=1"

# NetworkManager gets in the way, as usual
yum -C -y remove NetworkManager --setopt="clean_requirements_on_remove=1"


# Because memory is scarce resource in most cloud/virt environments,
# and because this impedes forensics, we are differing from the Fedora
# default of having /tmp on tmpfs.
echo "Disabling tmpfs for /tmp."
systemctl mask tmp.mount
%end
