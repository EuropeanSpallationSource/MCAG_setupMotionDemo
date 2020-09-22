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
  for m in *; do
    if test -d $m; then
      do_git_clean $m
    fi
  done
else
  for m in *; do
    if test -d $m; then
      (
        cd $m &&
         echo cd $m  &&
         echo make $1 &&
         make $1
      )
    fi
  done
fi
