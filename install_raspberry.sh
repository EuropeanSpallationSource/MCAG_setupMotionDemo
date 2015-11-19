#!/bin/sh

#add package x when y is not there
addpacketifneeded() {
  needed=$1
  tobeinstalled=$2
  if test -z "$tobeinstalled"; then
    tobeinstalled=$needed
  fi
  if ! which $needed ; then
    sudo apt-get install $tobeinstalled
  fi
}


#add user x
adduserifneeded() {
  user=$1
  if ! grep "$user" /etc/passwd >/dev/null 2>&1; then
      echo sudo adduser $user
      case $1 in
      guest|anonymous)
        sudo adduser $user
      ;;
      *)
        echo "unkown user $user"
        return
      ;;
    esac
  fi
  if ! grep $user /var/lib/samba/passdb.tdb >/dev/null; then
    echo smbpasswd -a $user
    sudo smbpasswd -a $user
  fi
}

#add user x to group y
addusertogroupifneeded() {
  user=$1
  grp=$2
  if ! grep "^$grp:.*$user" /etc/group >/dev/null 2>&1; then
    sudo adduser $user $grp
  fi
}

#create a superuser file
createsuperuserfile() {
  usr=$1
  usrfile=/etc/sudoers.d/$usr
  if ! test -e $usrfile; then
    echo "$usr ALL=(ALL)  ALL" >/tmp/$$ &&
    sudo cp /tmp/$$ $usrfile &&
    sudo chmod 444 $usrfile
  fi
}

fixhostname() {
  if grep raspberry /etc/hostname >/dev/null; then
    mac=$(ifconfig eth0 | grep b8:27:eb | sed -e "s/.*b8:27:eb:\(.*\)/\1/" -e "s/:/-/g")
    echo mac=$mac
    oldhostname=$(hostname)
    newhostname=raspi-$mac
    echo oldhostname=$oldhostname newhostname=$newhostname
    sed -i -e "s/$oldhostname/$newhostname/g" /etc/hosts
    echo $newhostname >/etc/hostname
  fi
}

# Here the stuff starts
echo Do you want to run apt-update/apt-ugrade ? [Y/n]
read yesno
case $yesno in
  n|N)
  ;;
   *)
     apt-get update && apt-get upgrade
   ;;
esac

fixhostname
addpacketifneeded avahi-browse      avahi-utils
addpacketifneeded rcs
addpacketifneeded smbd      samba
addpacketifneeded smbpasswd samba-common-bin
addpacketifneeded emacs
#addpacketifneeded nslookup dnsutils
addpacketifneeded xmodmap x11-xserver-utils


#www data
if test -d /var/www; then
  sudo chgrp -R www-data /var/www
  sudo chmod g+w /var/www
fi

#Samba workgroup
file=smb.conf
smbconf=/etc/samba/$file
if test -e $smbconf; then
  needrestart=0
  if ! test -e $smbconf.orig; then
    sudo cp -v $smbconf $smbconf.orig
  fi &&
  cp $smbconf /tmp/$$.$file &&
  if grep WORKGROUP $smbconf; then
    needrestart=1
    sed  -e "s/WORKGROUP/ESSS/" <$smbconf.orig >/tmp/$$.$file &&
    sudo cp /tmp/$$.$file $smbconf
  fi &&

  sudo mkdir -p /media/data/publicRW && sudo chmod 777 /media/data/publicRW &&

  if ! grep publicRW $smbconf >/dev/null; then
    needrestart=1
    cat >>/tmp/$$.$file <<EOF &&
[publicRW]
   create mask = 0777
   directory mask = 0777
   comment = publicRW
   read only = no
   locking = no
   path = /media/data/publicRW
   guest ok = yes
EOF
  sudo cp /tmp/$$.$file $smbconf
  fi &&
  if ! grep MYIP $smbconf >/dev/null; then
    needrestart=1
    cat >>/tmp/$$.$file <<EOF &&
[MYIP]
   comment = MYIP
   read only = yes
   path = /media/data/MYIP
   guest ok = yes
EOF
    sudo cp /tmp/$$.$file $smbconf
  fi
  if  test "$needrestart" = 1; then
    sudo /etc/init.d/samba restart
  fi
fi
#end of SAMBA


#Mount sda

if mount | grep /dev/sda1; then
  echo /dev/sda1 is mounted
else
  mkdir -p /media/data
  if sudo mount /dev/sda1 /media/data/; then
    echo mounted /dev/sda1 /media/data 
  fi
fi

if mount | grep /dev/sda1; then
  echo /dev/sda1 is mounted
  if mount | grep "/dev/sda1.*fat"; then
    echo "/dev/sda1 is fat"
    echo "Do you want to re-format /dev/sda1 to ext4 y/N"
    read yesNo
    case $yesNo in
     y|Y)
       echo re-formating
      if umount /dev/sda1; then
	 mkfs.ext4 /dev/sda1 && mount /dev/sda1 /media/data
      fi
     ;;
     *)
       echo no re-formating
     ;;
    esac
  fi
fi

if mount | grep "/dev/sda1.*ext4"; then
  fstab=/etc/fstab
  if ! grep "/dev/sda1.*ext4" $fstab; then
    cat <<-EOF >> $fstab
#Added by install_raspberry.sh
#/dev/sda1  /media/data          ext4    defaults,noatime  0       2
EOF
  fi 
fi

#############
#enable spi
blacklist=/etc/modprobe.d/raspi-blacklist.conf
if grep "^blacklist spi-bcm2708" $blacklist; then
  sed -i -e "s/blacklist spi-bcm2708/#blacklist spi-bcm2708/" $blacklist
  modprobe spi-bcm2708
fi

mydir=/media/data/MYIP
myfile=ifconfig.txt
sudo mkdir -p $mydir
iplogondata=/etc/network/if-up.d/iplogondata
cat >iplogondata.tmp.$$ <<EOF
#! /bin/sh
  if ! mount | grep /media/data; then
    if test -e /dev/sda5; then
      mount /dev/sda5 /media/data || :
    else
      mount /dev/sda1 /media/data || :
    fi
  fi
  mkdir -p $mydir
  if test -d $mydir; then
    rm -f $mydir/*.*.*.*
    ifconfig -a  >$mydir/$myfile
    someip=\$(grep "inet addr:"  "$mydir/$myfile" | grep -v ":127.0" | sed -e  "s/.*inet addr:\([.0-9]*\) .*/\1/")
    rm -f $mydir/*.*.*.*
    echo \$someip >$mydir/eth0.txt
    echo \$someip >$mydir/\$someip
  fi
EOF
sudo mv iplogondata.tmp.$$ $iplogondata &&
sudo chmod +x $iplogondata
for usr in guest; do
  echo usr=$usr
  if ! grep "$usr" /etc/passwd>/dev/null; then
    echo create user $usr [y/N]
    read yesno
    if test "$yesno" = y; then
      (
        adduserifneeded $usr
      )
    fi
  fi
done
