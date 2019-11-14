#!/bin/sh


# function to do a "git clean"
do_git_clean()
{
  (cd "$1" &&
      echo >.gitignore &&
      git clean -fd &&
      git checkout .gitignore
   )
}


if test "$1" = gitclean; then
  do_git_clean epics/base &&
  for m in epics/modules/*; do
    do_git_clean $m
  done
else
  echo make -C epics/base $1
  make -C epics/base $1 || :
  for m in epics/modules/*; do
    echo make -C $m $1 &&
    make -C $m $1
  done
fi
