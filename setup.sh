#!/bin/sh

./install-epics.sh
DIR=m-epics-IcePAP
if ! test -d "$DIR"; then	
  git clone https://github.com/EuropeanSpallationSource/$DIR.git &&
  (
    cd $DIR &&
    git checkout  93e44db7b1ec35d75
  )
fi
