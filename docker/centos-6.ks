install
url --url=http://mirror.centos.org/centos/6/os/x86_64/
lang en_US.UTF-8
keyboard uk
network --device eth0 --bootproto dhcp
rootpw --iscrypted $1$UKLtvLuY$kka6S665oCFmU7ivSDZzU.
authconfig --enableshadow --passalgo=sha512 --enablefingerprint
selinux --enforcing
timezone --utc Europe/London
repo --name="CentOS" --baseurl=http://mirror.centos.org/centos/6/os/x86_64/ --cost=100
repo --name="Updates" --baseurl=http://mirror.centos.org/centos-6/6/updates/x86_64/ --cost=100
# CentOSPlus is here ONLY for a libselinux patch.
# Once 6.6 is released, this should be removed
# http://lists.centos.org/pipermail/centos-devel/2014-May/010345.html
repo --name="CentOSPlus" --baseurl=http://mirror.centos.org/centos-6/6/centosplus/x86_64/ --cost=1000

clearpart --all --initlabel
part / --fstype ext4 --size=1024 --grow
reboot
%packages  --excludedocs --nobase
vim-minimal
yum
bash
bind-utils
grub
centos-release
shadow-utils
findutils
iputils
iproute
grub
-*-firmware
passwd

%end

%post
# randomize root password and lock root account
dd if=/dev/urandom count=50 | md5sum | passwd --stdin root
passwd -l root

# create necessary devices
/sbin/MAKEDEV /dev/console

# cleanup unwanted stuff

# ami-creator requires grub during the install, so we remove it (and
# its dependencies) in %post
rpm -e grub redhat-logos
rm -rf /boot

# some packages get installed even though we ask for them not to be,
# and they don't have any external dependencies that should make
# anaconda install them
rpm -e policycoreutils passwd
    

# Keep yum from installing documentation. It takes up too much space.
sed -i '/distroverpkg=centos-release/a tsflags=nodocs' /etc/yum.conf

# Remove files that are known to take up lots of space but leave
# directories intact since those may be required by new rpms.

# locales
#rm -f /usr/lib/locale/locale-archive

# nuking the locales breaks things. Lets not do that anymore
# strip most of the languages from the archive.
localedef --delete-from-archive $(localedef --list-archive | \
grep -v -i ^en | xargs )
# prep the archive template
mv /usr/lib/locale/locale-archive  /usr/lib/locale/locale-archive.tmpl
# rebuild archive
/usr/sbin/build-locale-archive
#empty the template
:>/usr/lib/locale/locale-archive.tmpl

#  man pages and documentation
find /usr/share/{man,doc,info,gnome/help} \
        -type f | xargs /bin/rm

#  sln
rm -f /sbin/sln

#  ldconfig
rm -rf /etc/ld.so.cache
rm -rf /var/cache/ldconfig/*


# Add centosplus repo enabled by default, with includepkg for
# libselinux updates until this patch lands in upstream.


cat >/etc/yum.repos.d/libselinux.repo <<EOF
[libselinux]
name=CentOS-\$releasever - libselinux
mirrorlist=http://mirrorlist.centos.org/?release=\$releasever&arch=\$basearch&repo=centosplus
#baseurl=http://mirror.centos.org/centos/\$releasever/centosplus/\$basearch/
gpgcheck=1
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-6
includepkgs=libselinux*

EOF



%end
