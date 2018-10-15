#!/bin/sh
  echo make -C epics/base clean
  make -C epics/base clean || :
  for m in epics/modules/*; do
    echo make -C $m clean &&
    make -C $m clean
  done
