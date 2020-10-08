#!/bin/sh

## Helper functions
create_BASE_SUPPORT_RELEASE_HOST_ARCH_local()
{
  file=$1 &&
  EPICS_MODULE=$2
  echo PWD=$PWD file=$file &&
  cat >$file <<EOF
EPICS_BASE  = $EPICS_ROOT/base
ASYN        = \$(EPICS_BASE)/../modules/asyn
EOF
  if test -z "$BUSY_VER_X_Y"; then
    echo BUSY=                         >>$file
  fi &&
  if test -z "$IPAC_VER_X_Y"; then
    echo IPAC=                         >>$file
  fi &&
  if test -z "$SEQ_VER_X_Y"; then
    echo SEQ=                          >>$file
  fi &&
  if test -z "$SNCSEQ_VER_X_Y"; then
    echo SNCSEQ=                       >>$file
  fi
  if test -z "$SSCAN_VER_X_Y"; then
    echo SSCAN=                        >>$file
  fi
if test -d "$EPICS_BASE/../modules/calc"; then
  cat >>$file <<EOF
CALC        = \$(EPICS_BASE)/../modules/calc
EOF
fi

case "$EPICS_MODULE" in
  ethercatmc)
    cat >>$file <<EOF
  MOTOR       = \$(EPICS_BASE)/../modules/motor
EOF
  ;;
  *)
  ;;
esac
}

configureEPICSmodule()
{
  EPICS_MODULE=$1
  (
    if ! test -d $EPICS_MODULE/configure; then
      return 0
    fi
    cd $EPICS_MODULE/configure &&
      git clean -f &&
      if egrep "^SUPPORT=|^EPICS_BASE=/" RELEASE; then
        echo 'include $(TOP)/configure/RELEASE_PATHS.local.$(EPICS_HOST_ARCH)' >RELEASE &&
        create_BASE_SUPPORT_RELEASE_HOST_ARCH_local RELEASE_PATHS.local.$EPICS_HOST_ARCH $EPICS_MODULE
      else
        echo "#empty" >RELEASE_PATHS.local &&
        echo "#empty" >RELEASE_LIBS.local &&
        create_BASE_SUPPORT_RELEASE_HOST_ARCH_local RELEASE_PATHS.local.$EPICS_HOST_ARCH $EPICS_MODULE
      fi
  )
}



# function to do a "git clean"
do_git_clean()
{
  (cd "$1" &&
      echo >.gitignore &&
      git clean -fd &&
      git checkout .gitignore
   )
}

############################################
# main
############################################
case "$1" in
  all)
    for m in asyn calc motor ethercatmc; do
      if test -d $m; then
        configureEPICSmodule $m
        (
          cd $m &&
            echo cd $m &&
            echo make  &&
            make
        )
      fi
    done
    ;;
  asyn|ethercatmc|motor)
    m=$1
    if test -d $m; then
      configureEPICSmodule $m
      (
        cd $m &&
          echo cd $m &&
          echo make  &&
          make
      )
    fi
  ;;
  clean|distclean)
    for m in *; do
      if test -d $m; then
        (
          cd $m &&
            echo cd $m &&
            echo make $1 &&
            make $1
        )
      fi
    done
  ;;
  gitclean)
    for m in *; do
      if test -d $m; then
        do_git_clean $m
      fi
    done
  ;;
esac

