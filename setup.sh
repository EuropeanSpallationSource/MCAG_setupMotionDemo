#!/bin/sh

./install-epics.sh
DIR=m-epics-IcePAP
if ! test -d "$DIR"; then	
  git clone https://github.com/EuropeanSpallationSource/$DIR.git &&
  (
    cd $DIR &&
    git checkout 722926e3751d24c9ca1f3b9
  )
fi
