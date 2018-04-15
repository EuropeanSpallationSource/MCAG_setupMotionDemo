#!/bin/sh
# Macros, which module is where
#Clean up from EEE
EPICS_BASE=
EPICS_BASES_PATH=
EPICS_ENV_PATH=
EPICS_HOST_ARCH=
EPICS_MODULES_PATH=

uname_s=$(uname -s 2>/dev/null || echo unknown)
uname_m=$(uname -m 2>/dev/null || echo unknown)

BASH_ALIAS_EPICS=./.epics.$(hostname).$uname_s.$uname_m

#Where is EPICS base
EPICS_ROOT=$PWD/epics
EPICS_BASE=$EPICS_ROOT/base

EPICS_BASE_VER=3.15.5


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
    cd re2c-code-git/re2c &&
    addpacketifneeded automake &&
    ./autogen.sh &&
    ./configure &&
    make &&
    echo PWD=$PWD $FSUDO make install &&
    $FSUDO make install
  )
}
run_make_in_dir()
{
  dir=$1 &&
  echo cd $dir &&
  (
    cd $dir &&
    $FSUDO make -f Makefile || {
    echo >&2 PWD=$PWD Can not make
    exit 1
  }
  )
}

patch_CONFIG_gnuCommon()
{
  (
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
      cat <<\EOF > "$file.patch"
diff --git a/CONFIG.gnuCommon b/CONFIG.gnuCommon
index f054802..d59a420 100644
--- a/CONFIG.gnuCommon
+++ b/CONFIG.gnuCommon
@@ -27,16 +27,16 @@ GPROF_CFLAGS_YES = -pg
 CODE_CFLAGS = $(PROF_CFLAGS_$(PROFILE)) $(GPROF_CFLAGS_$(GPROF))
 WARN_CFLAGS_YES = -Wall
 WARN_CFLAGS_NO = -w
-OPT_CFLAGS_YES = -O3
-OPT_CFLAGS_NO = -g
+OPT_CFLAGS_YES = -O0 -g
+OPT_CFLAGS_NO = -g -O0
 
 PROF_CXXFLAGS_YES = -p
 GPROF_CXXFLAGS_YES = -pg
 CODE_CXXFLAGS = $(PROF_CXXFLAGS_$(PROFILE)) $(GPROF_CXXFLAGS_$(GPROF))
 WARN_CXXFLAGS_YES = -Wall
 WARN_CXXFLAGS_NO = -w
-OPT_CXXFLAGS_YES = -O3
-OPT_CXXFLAGS_NO = -g
+OPT_CXXFLAGS_YES = -O0 -g
+OPT_CXXFLAGS_NO = -g -O0
 
 CODE_LDFLAGS = $(PROF_CXXFLAGS_$(PROFILE)) $(GPROF_CXXFLAGS_$(GPROF))
 
EOF
      ;;
      *)
      echo >&2 "PWD=$PWD Can not patch $file, not supported"
      exit 1
    esac &&
    patch < "$file.patch"
  )
}

#############
create_BASE_SUPPORT_RELEASE_PATH_local()
{
  file=$1 &&
  echo PWD=$PWD file=$file &&
  cat >$file <<EOF
EPICS_BASE  = $EPICS_ROOT/base
SUPPORT     = \$(EPICS_BASE)/../modules
EOF
}
  
#############
create_MOTOR_DRIVERS_RELEASE_LIBS_local()
{
  file=$1 &&
  echo PWD=$PWD file=$file &&
  cat >$file <<EOF
ASYN        = \$(EPICS_BASE)/../modules/asyn
MOTOR       = \$(EPICS_BASE)/../modules/motor
EOF
if test -d "$EPICS_BASE/../modules/calc"; then
  cat >>$file <<EOF
CALC        = \$(EPICS_BASE)/../modules/calc
EOF
fi
}

#############
create_ASYN_MOTOR_RELEASE_LIBS_local()
{
  file=$1 &&
  echo PWD=$PWD file=$file &&
  cat >$file <<EOF
ASYN        = \$(EPICS_BASE)/../modules/asyn
MOTOR       = \$(EPICS_BASE)/../modules/motor
SUPPORT     = \$(EPICS_BASE)/../modules
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



#############
compileEPICSmodule()
{
  EPICS_MODULE=$1
  (
    cd $EPICS_ROOT/modules/$EPICS_MODULE/configure &&
      case $EPICS_MODULE in
      *asyn*|*calc*)
        create_BASE_SUPPORT_RELEASE_PATH_local   RELEASE.$EPICS_HOST_ARCH.Common &&
        create_ASYN_MOTOR_RELEASE_LIBS_local     CONFIG_SITE.$EPICS_HOST_ARCH.Common
        ;;
      *motor*)
        create_BASE_SUPPORT_RELEASE_PATH_local   RELEASE_PATHS.local &&
        create_MOTOR_DRIVERS_RELEASE_LIBS_local  RELEASE_LIBS.local &&
        disable_MOTOR_DRIVERS                    RELEASE_LIBS.local
        ;;
      *EthercatMC*)
        create_BASE_SUPPORT_RELEASE_PATH_local   RELEASE_PATHS.local &&
        create_MOTOR_DRIVERS_RELEASE_LIBS_local  RELEASE_LIBS.local
        ;;
      *)
        echo >&2 unknown module $EPICS_MODULE
        exit 1
      esac
  ) &&
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


# Set up EPICS_HOST_ARCH
UNAME=$(uname)
echo UNAME=$UNAME EPICS_HOST_ARCH=$EPICS_HOST_ARCH
case $UNAME in
MINGW64_NT-6.1)
  EPICS_HOST_ARCH=windows-x64-mingw
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

while getopts ":i:m" opt; do
  case $opt in
    i)
      INSTALL_EPICS=$OPTARG
      ;;
    m)
      EPICS_MODULE=$OPTARG
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

CP="$FSUDO cp"
LN="$FSUDO ln"
MKDIR="$FSUDO mkdir"
MV="$FSUDO mv"
RM="$FSUDO rm"

export CP FSUDO LN MKDIR MV RM SUDO


if test -n "$EPICS_MODULE"; then
  . $BASH_ALIAS_EPICS &&
  compileEPICSmodule $EPICS_MODULE || {
    echo >&2 failed $EPICS_MODULE
    exit 1
  }
  exit
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
if test "\$LD_LIBRARY_PATH"; then
  export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:\$EPICS_BASE_LIB
else
  export LD_LIBRARY_PATH=\$EPICS_EXT_LIB
fi
export PATH=\$PATH:\$EPICS_BASE_BIN:\$EPICS_EXT_BIN
export SUPPORT=\${EPICS_ROOT}/support
EOF
. $BASH_ALIAS_EPICS &&
set | grep EPICS &&
$CP $BASH_ALIAS_EPICS $EPICS_ROOT/.epics.$EPICS_HOST_ARCH &&
$CP $BASH_ALIAS_EPICS ../.. &&
################

(
  addpacketifneeded make &&
  # We need gcc and g++: gcc-g++ under Scientifc Linux
  if ! type g++ >/dev/null 2>/dev/null; then
    echo $APTGET gcc-c++
    $APTGET gcc-c++
  fi
  # We need g++
  if ! type g++ >/dev/null 2>/dev/null; then
    echo $APTGET g++
    $APTGET g++
  fi &&
  #We need readline
  # Mac OS: /usr/include/readline/readline.h
  # Linux: /usr/include/readline.h
  if ! test -r /usr/include/readline/readline.h; then
    test -r /mingw64/include/editline/readline.h ||   
    test -r /usr/include/readline.h ||
    $APTGET readline-devel ||
    $APTGET libreadline-dev ||
    {
      echo >&2 can not install readline-devel
      exit 1
    }
  fi &&
  if test "$EPICS_DEBUG" = y; then
    patch_CONFIG_gnuCommon $EPICS_ROOT/base/configure
  fi &&
  run_make_in_dir $EPICS_ROOT/base || {
    echo >&2 failed in $PWD
    exit 1
  }
) &&

run_make_in_dir ${EPICS_BASE} || {
  echo >&2 failed in ${EPICS_BASE}
  exit 1
}

#################################
# compile asyn
for EPICS_MODULE in asyn motor EthercatMC ; do
  compileEPICSmodule $EPICS_MODULE || {
    echo >&2 failed $EPICS_MODULE
    exit 1
  }
done


echo install $EPICS_ROOT OK

