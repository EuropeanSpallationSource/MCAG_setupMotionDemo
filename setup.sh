#!/bin/sh

DIR=MCAG_Base_Project

./install-epics.sh "$@" &&
if ! test -d "$DIR"; then	
  git clone https://github.com/EuropeanSpallationSource/$DIR.git &&
  (
    cd $DIR &&
      git checkout f14022e871acd3bf837e155fe8b7f0ed0
  )
fi
