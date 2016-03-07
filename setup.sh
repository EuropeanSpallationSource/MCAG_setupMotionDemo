#!/bin/sh

#if type apt-get >/dev/null; then
#  if $(uname -m | grep armv6 >/dev/null); then
#    sudo ./install_raspberry.sh
#  fi
#fi
./install-epics.sh
DIR=MCAG_Base_Project
if ! test -d "$DIR"; then	
  git clone https://github.com/EuropeanSpallationSource/$DIR.git &&
  (
    cd $DIR &&
      git checkout f14022e871acd3bf837e155fe8b7f0ed0
  )
fi
