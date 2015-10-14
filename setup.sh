#!/bin/sh

./install-epics.sh
DIR=m-epics-IcePAP
if ! test -d "$DIR"; then	
  git clone https://github.com/EuropeanSpallationSource/$DIR.git &&
  (
    cd $DIR &&
    git checkout  0a3597b9f4ce113fa8cd4add853ed
  )
fi
