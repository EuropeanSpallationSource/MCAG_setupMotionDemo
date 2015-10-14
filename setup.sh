#!/bin/sh

./install-epics.sh
DIR=m-epics-IcePAP
if ! test -d "$DIR"; then	
  git clone https://github.com/EuropeanSpallationSource/$DIR.git &&
  (
    cd $DIR &&
    git checkout 11eab43836a9376fd0
  )
fi
