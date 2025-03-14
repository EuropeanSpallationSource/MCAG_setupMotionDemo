#!/bin/sh
# Macros, which module is where
#Clean up from EEE
EPICS_BASE=
EPICS_BASES_PATH=
EPICS_ENV_PATH=
EPICS_HOST_ARCH=
EPICS_MODULES_PATH=

MAKE=make
UNAME_A=$(uname -a)
case $UNAME_A in
  FreeBSD*BHF*amd64)
    SUDO=doas
    MAKE=gmake
  ;;
  FreeBSD*)
    MAKE=gmake
  ;;
  *CYGWIN*|*MING*)
    SUDO=
  ;;
  *)
    SUDO=sudo
  ;;
esac
APTGET=/bin/false
if type apt-get >/dev/null 2>/dev/null; then
  APTGET="$SUDO apt-get install"
fi
if type yum >/dev/null 2>/dev/null; then
  APTGET="$SUDO /usr/bin/yum install"
fi
# port (Mac Ports)
if test -x /opt/local/bin/port; then
  APTGET="$SUDO port install"
fi
# brew (Mac)
if test -x /usr/local/bin/brew; then
  APTGET="$SUDO brew install"
fi
if test -x /usr/sbin/pkg; then
  APTGET="$SUDO pkg install -U"
fi

if type pacman >/dev/null 2>/dev/null; then
  APTGET="pacman -S"
fi


if test "$APTGET" = /bin/false;
then
  echo >&1 "Cant find a package manager (like apt, yu, port, pacman)"
  exit 1
fi
echo APTGET=$APTGET
export APTGET

uname_s=$(uname -s 2>/dev/null || echo unknown)
uname_m=$(uname -m 2>/dev/null || echo unknown)

BASH_ALIAS_EPICS=./.epics.$(hostname).$uname_s.$uname_m

#Where is EPICS base
EPICS_ROOT=$PWD/epics
EPICS_BASE=$EPICS_ROOT/base

EPICS_BASE_VER=7.0.3


export EPICS_BASE EPICS_BASES_PATH EPICS_ENV_PATH EPICS_HOST_ARCH EPICS_MODULES_PATH


#########################################################
# shell functions
#
addpacketifneeded() {
  needed=$1
  tobeinstalled=$2
  if test -z "$tobeinstalled"; then
    tobeinstalled=$needed
  fi
  if ! which $needed ; then
    echo $APTGET $tobeinstalled
    $APTGET $tobeinstalled
  fi
}

install_re2c()
{
  cd $EPICS_ROOT &&
  if ! test -d re2c-code-git; then
    git clone git://git.code.sf.net/p/re2c/code-git re2c-code-git.$$.tmp &&
    $MV re2c-code-git.$$.tmp  re2c-code-git
  fi &&
  (
    cd re2c-code-git &&
    addpacketifneeded automake &&
    ./autogen.sh &&
    ./configure &&
    $MAKE &&
    echo PWD=$PWD $FSUDO $MAKE install &&
    $FSUDO $MAKE install
  )
}
run_make_in_dir()
{
  dir=$1 &&
  if echo $dir | grep -i "\.not"; then
    return
  fi
  echo cd $dir &&
  (
    cd $dir &&
    $FSUDO $MAKE -f Makefile || {
    echo >&2 PWD=$PWD Can not $MAKE
    exit 1
  }
  )
}

patch_CONFIG_gnuCommon()
{
  (
    OLDPWD=$PWD
    file=CONFIG.gnuCommon
    export file
    cd "$1" &&
    if grep "OPT_CXXFLAGS_NO *= *-g *-O0" $file >/dev/null; then
      echo PWD=$PWD patch $file not needed &&
      return
    fi &&
    echo PWD=$PWD patch $file &&
    if ! test -e $file.original; then
      $CP $file $file.original
    fi &&
    $CP $file.original $file &&
    case $EPICS_BASE_VER in
      *3.14.12.3*|*3.14.12.5*|*3.15.1*|*3.15.2*|*3.15.5*)
      cp -v $OLDPWD/D3.14-15.patch $file.patch
      ;;
      *7.0.3*)
      cp -v $OLDPWD/7.0.3.patch $file.patch
      ;;
      *)
      echo >&2 "PWD=$PWD Can not patch $file, not supported"
      exit 1
    esac &&
    patch < "$file.patch"
  )
}

#############
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
  if test -d "$EPICS_BASE/../modules/seq"; then
    cat >>$file <<EOF
SNCSEQ        = \$(EPICS_BASE)/../modules/seq
EOF
  elif test -z "$SNCSEQ_VER_X_Y"; then
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
if test -d "$EPICS_BASE/../modules/ads"; then
  cat >>$file <<EOF
ADS         = \$(EPICS_BASE)/../modules/ads
EOF
fi

case "$EPICS_MODULE" in
  ethercatmc|motor*)
    cat >>$file <<EOF
MOTOR       = \$(EPICS_BASE)/../modules/motor
EOF
if test -d "$EPICS_BASE/../modules/StreamDevice"; then
  cat >>$file <<EOF
STREAM       = \$(EPICS_BASE)/../modules/StreamDevice
EOF
  fi
  if test -d "$EPICS_BASE/../modules/pvxs"; then
  cat >>$file <<EOF
PVXS         = \$(EPICS_BASE)/../modules/pvxs
EOF
  fi
  if ! test -f "$EPICS_BASE/modules/pvAccess/Makefile"; then
    echo "No Support for pvAccess"
    EMCMFILE=$EPICS_BASE/../modules/ethercatmc/ethercatmcExApp/src/Makefile
    if grep "ifdef  *BASE_7_0" $EMCMFILE; then
      sed -e "s/ifdef  *BASE_7_0/ifdef XPVABASE_7_0/g" <"$EMCMFILE" >/tmp/$$ &&
      mv -f /tmp/$$ "$EMCMFILE"
    fi
  else
    echo "Support for pvAccess"
  fi
  ;;
  cacm)
  if test -d "$EPICS_BASE/../modules/pcas"; then
  cat >>$file <<EOF
PCAS         = \$(EPICS_BASE)/../modules/pcas
EOF
fi
;;
  *)
  ;;
esac
}

#############
disable_MOTOR_DRIVERS()
{
  file=$1 &&
  echo PWD=$PWD file=$file &&
  cat >>$file <<EOF
NO_MOTOR_DELTATAUSRC = y
NO_MOTOR_OMSSRC = y
NO_MOTOR_OMSASYNSRC = y
NO_MOTOR_NEWPORTSRC = y
NO_MOTOR_IMSSRC = y
NO_MOTOR_ACSSRC = y
NO_MOTOR_MCLENNANSRC = y
NO_MOTOR_PISRC = y
NO_MOTOR_PIGCS2SRC = y
NO_MOTOR_MICROMOSRC = y
NO_MOTOR_MICOSSRC = y
NO_MOTOR_FAULHABERSRC = y
NO_MOTOR_PC6KSRC = y
NO_MOTOR_NEWFOCUSSRC = y
NO_MOTOR_ACSTECH80SRC = y
NO_MOTOR_ORIELSRC = y
NO_MOTOR_THORLABSSRC = y
NO_MOTOR_SMARTMOTORSRC = y
NO_MOTOR_PIJENASRC = y
NO_MOTOR_KOHZUSRC = y
NO_MOTOR_ATTOCUBESRC = y
NO_MOTOR_AEROTECHSRC = y
NO_MOTOR_HYTECSRC = y
NO_MOTOR_ACRSRC = y
NO_MOTOR_SMARACTMCSSRC = y
NO_MOTOR_NPOINTSRC = y
NO_MOTOR_MICRONIXSRC = y
NO_MOTOR_PHYTRONSRC = y
NO_MOTOR_AMCISRC = y
NO_MOTOR_MXMOTORSRC = y
EOF
}



############
checkoutEPICSmodule()
{
  EPICS_MODULE=$1
  if echo $EPICS_MODULE | grep -i "\.not"; then
    return
  fi
  if ! test -d $EPICS_ROOT/modules/$EPICS_MODULE/configure; then
    git submodule init epics/modules/$EPICS_MODULE &&
    git submodule update epics/modules/$EPICS_MODULE
  fi
}

configureEPICSmodule()
{
  EPICS_MODULE=$1
  (
    if ! test -d $EPICS_ROOT/modules/$EPICS_MODULE/configure; then
      return 0
    fi
    cd $EPICS_ROOT/modules/$EPICS_MODULE/configure &&
      git clean -f &&
      if grep '^-include \$(TOP)/../RELEASE.\$(EPICS_HOST_ARCH).local' RELEASE; then
        echo "$EPICS_MODULE: RELEASE style RELEASE.EPICS_HOST_ARCH.local"
        echo 'include $(TOP)/configure/RELEASE_PATHS.local.$(EPICS_HOST_ARCH)' >RELEASE.local &&
        if grep -E "[A-Z_]+=/[a-zA-Z]" RELEASE; then
          echo 'Commenting out hard-coded paths' &&
          sed -e 's!^\([A-Z][A-Z_]*=/[a-zA-Z]\)!#\1!g' <RELEASE >/tmp/$$ &&
          mv /tmp/$$ RELEASE
        fi &&
        create_BASE_SUPPORT_RELEASE_HOST_ARCH_local RELEASE_PATHS.local.$EPICS_HOST_ARCH $EPICS_MODULE
      elif egrep "^SUPPORT=|^EPICS_BASE *= */" RELEASE; then
        echo "$EPICS_MODULE: RELEASE style RELEASE-allows-no-local"
        echo 'include $(TOP)/configure/RELEASE_PATHS.local.$(EPICS_HOST_ARCH)' >RELEASE &&
        create_BASE_SUPPORT_RELEASE_HOST_ARCH_local RELEASE_PATHS.local.$EPICS_HOST_ARCH $EPICS_MODULE
      else
        echo "$EPICS_MODULE: RELEASE style RELEASE_PATHS.local.EPICS_HOST_ARCH"
        echo "#empty" >RELEASE_PATHS.local &&
        echo "#empty" >RELEASE_LIBS.local &&
        create_BASE_SUPPORT_RELEASE_HOST_ARCH_local RELEASE_PATHS.local.$EPICS_HOST_ARCH $EPICS_MODULE &&
        disable_MOTOR_DRIVERS                       RELEASE_PATHS.local.$EPICS_HOST_ARCH
      fi &&
      if test $EPICS_MODULE=asyn && test -d /usr/include/tirpc; then
        if ! grep -q "^TIRPC=YES" CONFIG_SITE.Common.$EPICS_HOST_ARCH; then
          echo TIRPC=YES >> CONFIG_SITE.Common.$EPICS_HOST_ARCH
        fi
      fi
    exit
  )
}

compileEPICSmodule()
{
  EPICS_MODULE=$1
  (
    run_make_in_dir $EPICS_ROOT/modules/$EPICS_MODULE
  ) || {
    echo >&2 failed $EPICS_MODULE
    exit 1
  }
}

#########################################################
# main
#

##
if ! test -d $EPICS_BASE/startup; then
  git submodule init epics/base &&
  git submodule update --recursive epics/base || {
    echo >&2 error with submodule
    exit 1
  }
  (
    cd epics/base &&
      git submodule init &&
      git submodule update
  )
fi

# Set up EPICS_HOST_ARCH
UNAME=$(uname)
echo UNAME=$UNAME EPICS_HOST_ARCH=$EPICS_HOST_ARCH
case $UNAME in
MINGW64_NT*)
  EPICS_HOST_ARCH=windows-x64-mingw
  ;;
Linux)
  case $(uname -m) in
       ppc)
         EPICS_HOST_ARCH=linux-ppc
         ;;
       *)
         EPICS_HOST_ARCH=$($EPICS_BASE/startup/EpicsHostArch) || {
           echo >&2 EPICS_HOST_ARCH failed
           exit 1
         }
  esac
  ;;
FreeBSD)
  case $(uname -m) in
  amd64)
    EPICS_HOST_ARCH=freebsd-x86_64
    ;;
       *)
    echo >&2 EPICS_HOST_ARCH failed for FreeBSD
    exit 1
  esac
  ;;
*)
  EPICS_HOST_ARCH=$($EPICS_BASE/startup/EpicsHostArch) || {
    echo >&2 EPICS_HOST_ARCH failed
    exit 1
  }
  ;;
esac
echo UNAME=$UNAME EPICS_HOST_ARCH=$EPICS_HOST_ARCH

# here we know the EPICS_HOST_ARCH
export EPICS_HOST_ARCH
EPICS_BASE_BIN=${EPICS_BASE}/bin/$EPICS_HOST_ARCH
EPICS_EXT_BIN=${EPICS_EXT}/bin/$EPICS_HOST_ARCH
PATH=$PATH:$EPICS_BASE_BIN:$EPICS_EXT_BIN
EPICS_EXT_LIB=${EPICS_EXT}/lib/$EPICS_HOST_ARCH
if test "${LD_LIBRARY_PATH}"; then
  export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$EPICS_BASE_LIB
else
  export LD_LIBRARY_PATH=$EPICS_EXT_LIB
fi
echo PATH=$PATH
export EPICS_BASE_BIN EPICS_EXT EPICS_EXT_LIB EPICS_EXT_BIN PATH LD_LIBRARY_PATH



# Automatic install option for scripted installation
INSTALL_EPICS=""

while getopts "i:m:" opt; do
  echo opt=$opt
  case $opt in
    h)
      echo >&2 "usage $0 [options]"
      echo >&2 "      $0 -i y # install without prompting"
      echo >&2 "      $0 -m <module> # install <module>"
      exit 1
      ;;
    i)
      INSTALL_EPICS=$OPTARG
      ;;
    m)
      EPICS_MODULE=$OPTARG
      echo EPICS_MODULE=$EPICS_MODULE
      INSTALL_EPICS=y
      ;;
    :)
      echo "Option -i needs an argument (y for automatic installation of EPICS, n for skipping installation)."
      echo "Option -m needs the module to compile as an argument"
      exit 1
   esac
done


if test -z "$INSTALL_EPICS"; then
  echo EPICS_ROOT=$EPICS_ROOT
  echo Do you want to compile EPICS in $EPICS_ROOT ? [y/N]
  read yesno
  INSTALL_EPICS=$yesno
fi

case $INSTALL_EPICS in
  y|Y)
  ;;
  *)
  exit 1
esac


if $(echo "$EPICS_ROOT" | grep -q /usr/local); then
  echo EPICS_ROOT=$EPICS_ROOT
  echo EPICS_DOWNLOAD=$EPICS_DOWNLOAD
  if ! test -w "$EPICS_DOWNLOAD"; then
    FSUDO=sudo
  fi
fi

CP="echo PWD=$PWD && $FSUDO cp -v"
LN="$FSUDO ln"
MKDIR="$FSUDO mkdir"
MV="$FSUDO mv"
RM="$FSUDO rm"

export CP FSUDO LN MKDIR MV RM SUDO


if test -n "$EPICS_MODULE"; then
    if test $EPICS_MODULE = base; then
       if ! test -d $EPICS_ROOT/$EPICS_MODULE; then
           git submodule init epics/$EPICS_MODULE &&
           git submodule update epics/$EPICS_MODULE &&
           run_make_in_dir ${EPICS_BASE} || {
             echo >&2 failed in ${EPICS_BASE}
             exit 1
           }
       fi
    elif test $EPICS_MODULE = re2c; then
         install_re2c
    else
      . $BASH_ALIAS_EPICS &&
      checkoutEPICSmodule $EPICS_MODULE &&
      configureEPICSmodule $EPICS_MODULE &&
      compileEPICSmodule $EPICS_MODULE || {
        echo >&2 failed $EPICS_MODULE
        exit 1
      }
    fi
fi



#update .epics
cat >${BASH_ALIAS_EPICS} <<EOF &&
EPICS_BASE=
EPICS_BASES_PATH=
EPICS_ENV_PATH=
EPICS_HOST_ARCH=
EPICS_MODULES_PATH=
export EPICS_BASE EPICS_BASES_PATH EPICS_ENV_PATH EPICS_HOST_ARCH EPICS_MODULES_PATH
export EPICS_DEBUG=$EPICS_DEBUG
export EPICS_DOWNLOAD=$EPICS_DOWNLOAD
export EPICS_ROOT=$EPICS_ROOT
export EPICS_BASE=\$EPICS_ROOT/base
export EPICS_EXT=\${EPICS_ROOT}/extensions
export EPICS_HOST_ARCH=$EPICS_HOST_ARCH
export EPICS_EXT_BIN=${EPICS_EXT}/bin/\$EPICS_HOST_ARCH
export EPICS_EXT_LIB=${EPICS_EXT}/lib/\$EPICS_HOST_ARCH
export EPICS_MODULES=\$EPICS_ROOT/modules
export EPICS_BASE_BIN=\${EPICS_BASE}/bin/\$EPICS_HOST_ARCH
export EPICS_BASE_LIB=\${EPICS_BASE}/lib/\$EPICS_HOST_ARCH
export LD_LIBRARY_PATH=\${EPICS_BASE_LIB}:\$LD_LIBRARY_PATH
export SUPPORT=\${EPICS_ROOT}/support
if test "\$(which caget)" != \$EPICS_BASE_BIN; then
  export PATH=\$EPICS_BASE_BIN:\$EPICS_EXT_BIN:\$PATH
  if test "\$LD_LIBRARY_PATH"; then
    export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:\$EPICS_BASE_LIB
  else
    export LD_LIBRARY_PATH=\$EPICS_EXT_LIB
  fi
fi
EOF
if test -d epics/modules/pvxs; then
cat >>${BASH_ALIAS_EPICS} <<EOF
export PATH=\$PATH:\$EPICS_ROOT/modules/pvxs/bin/$EPICS_HOST_ARCH
EOF
fi

. $BASH_ALIAS_EPICS &&
set | grep EPICS &&
$CP $BASH_ALIAS_EPICS $EPICS_ROOT/.epics.$EPICS_HOST_ARCH &&
$CP $BASH_ALIAS_EPICS ../.. &&
################

(
  addpacketifneeded $MAKE &&
  # We need gcc and g++: gcc-g++ under Scientifc Linux
  # or gcc
  # FreeBSD has c++
  if ! type c++ >/dev/null 2>/dev/null; then
    if ! type g++ >/dev/null 2>/dev/null; then
      echo $APTGET gcc-c++
      $APTGET gcc-c++ || $APTGET gcc
    fi
    # We need g++
    if ! type g++ >/dev/null 2>/dev/null; then
      echo $APTGET g++
      $APTGET g++
    fi
  fi &&
  #We need readline
  # Mac OS: /usr/include/readline/readline.h
  # Linux: /usr/include/readline.h
  if ! test -r /usr/include/readline/readline.h &&
    ! test -r /mingw64/include/editline/readline.h &&
    ! test -r /usr/include/readline.h &&
    ! test -r /opt/local/include/readline/readline.h &&
    ! test -r /usr/local/include/readline/readline.h
  then
    $APTGET readline-devel ||
    $APTGET libreadline-dev ||
    $APTGET libreadline6-dev ||
    $APTGET devel/readline ||
    $APTGET libreadline-devel ||
    {
      echo >&2 can not install readline-devel
      exit 1
    }
  fi &&
  if test -d epics/modules/pvxs; then
    if ! test -r /usr/include/event2/event.h &&
      ! test -r /opt/local/include//event2/event.h; then
      $APTGET libevent-dev ||
      $APTGET libevent-devel ||
      $APTGET libevent
    fi
  fi &&
  if test "$EPICS_DEBUG" = y; then
    patch_CONFIG_gnuCommon $EPICS_ROOT/base/configure
  fi
) &&
if test -z "$EPICS_MODULE"; then
  run_make_in_dir ${EPICS_BASE} || {
    echo >&2 failed in ${EPICS_BASE}
    exit 1
  }
fi

#################################
# In case we don't have a specic module specified,
# build a list of well known modules needed for
# Motion Control
if test -z "$EPICS_MODULE"; then
  for EPICS_MODULE in asyn calc motor ethercatmc; do
    if ! test -d $EPICS_MODULE; then
      checkoutEPICSmodule $EPICS_MODULE || {
        echo >&2 failed $EPICS_MODULE
        exit 1
      }
    fi
  done
  # configure modules
  for EPICS_MODULE in asyn ads seq calc pcas cacm motor pvxs ethercatmc; do
    # Remove empty directories
    rmdir $EPICS_ROOT/modules/$EPICS_MODULE || :
    if ! test -d $EPICS_ROOT/modules/$EPICS_MODULE; then
      continue
    fi
    configureEPICSmodule $EPICS_MODULE || {
      echo >&2 failed $EPICS_MODULE
      exit 1
    }
  done
  # compile modules
  (
    cd epics/modules &&
      for EPICS_MODULE in calc asyn ads motor * ; do
        if test -d $EPICS_MODULE; then
          compileEPICSmodule $EPICS_MODULE || {
            echo >&2 failed $EPICS_MODULE
            exit 1
          }
        fi
      done
  )
fi

echo install $EPICS_ROOT OK


