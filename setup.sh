#!/bin/sh

DIRT=MCAG_Base_Project
DIRI=m-epics-IcePAP

./install-epics.sh "$@" &&
if ! test -d "$DIRT"; then	
  git clone https://github.com/EuropeanSpallationSource/$TDIR.git &&
  (
    cd $DIR &&
      git checkout f14022e871acd3bf837e155fe8b7f0ed0
  )
fi

if ! test -d "$DIRI"; then	
  git clone https://github.com/EuropeanSpallationSource/$TDIR.git &&
  (
    cd $DIR &&
      git checkout 160429_Real_IcePAP_axis_2
  )
fi
