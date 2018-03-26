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

while getopts ":i:" opt; do
  case $opt in
    i)
      INSTALL_EPICS=$OPTARG
      ;;
    :)
      echo "Option -i needs an argument (y for automatic installation of EPICS, n for skipping installation)."
      exit 1
   esac
done

if test -z "$INSTALL_EPICS"; then
  echo EPICS_ROOT=$EPICS_ROOT
  echo Do you want to install EPICS in $EPICS_ROOT ? [y/N]
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
echo install $EPICS_ROOT OK


