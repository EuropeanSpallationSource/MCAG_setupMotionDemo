#!/bin/sh

./install-epics.sh
DIR=m-epics-IcePAP
if ! test -d "$DIR"; then	
  git clone https://github.com/EuropeanSpallationSource/$DIR.git &&
  (
    cd $DIR &&
    git checkout 151013_1053_debug_CSS
  )
fi
