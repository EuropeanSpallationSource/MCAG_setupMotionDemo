#!/bin/sh

EPICS_DOWNLOAD=$PWD/epics-for-Motion

uname_s=$(uname -s 2>/dev/null || echo unknown)
uname_m=$(uname -m 2>/dev/null || echo unknown)

BASH_ALIAS_EPICS=./.epics.$(hostname).$uname_s.$uname_m

#Version of base
EPICS_BASE_VER=3.15.4
BASE_VER=GIT
EPICS_BASE_GIT_VER=R${EPICS_BASE_VER}


#Version for ASYN
#ASYNVER=4-21
ASYN_GIT_VER=R4-31

#AXIS_GIT_VER=master
AXIS_GIT_VER=torsten/17123-move-doc-submodules-axisCore-xx

# Debug version for e.g. kdbg
EPICS_DEBUG=n
if test "$EPICS_DEBUG" = ""; then
  if type kdbg; then
    EPICS_DEBUG=y
  fi
fi
#Where are the binaries of EPICS
if ! test "$EPICS_DOWNLOAD"; then
  EPICS_DOWNLOAD=/usr/local/epics
fi

EPICS_ROOT=$EPICS_DOWNLOAD/EPICS_BASE_${EPICS_BASE_VER}
if test -n "$BASE_VER"; then
  EPICS_ROOT=${EPICS_ROOT}_GIT
fi
if test -n "$ASYN_GIT_VER"; then
  ASYN_VER_X_Y=asyn$ASYN_GIT_VER
  EPICS_ROOT=${EPICS_ROOT}_ASYN_${ASYN_GIT_VER}
fi

if test "$EPICS_DEBUG" = y; then
  EPICS_ROOT=${EPICS_ROOT}_DBG
fi
EPICS_BASE=$EPICS_ROOT/base
EPICS_MODULES=$EPICS_ROOT/modules

echo EPICS_ROOT=$EPICS_ROOT
EPICS_ROOT=$(echo $EPICS_ROOT | sed -e "s%/[^/][^/]*/\.\./%/%")


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

export EPICS_ROOT EPICS_BASE EPICS_MODULES EPICS_BASE_VER EPICS_ROOT EPICS_DEBUG
export EPICS_EXT=${EPICS_ROOT}/extensions
#########################
#apt or yum or port
if uname -a | egrep "CYGWIN|MING" >/dev/null; then
  SUDO=
else
  SUDO=sudo
fi
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
export APTGET
#########################

create_AXIS_RELEASE_PATH_local()
{
  file=$1 &&
	echo PWD=$PWD file=$file &&
	cat >$file <<EOF
EPICS_BASE  = $EPICS_ROOT/base
SUPPORT     = \$(EPICS_BASE)/../support
EOF
}
	
create_AXIS_RELEASE_LIBS_local()
{
  file=$1 &&
	echo PWD=$PWD file=$file &&
	cat >$file <<EOF
ASYN        = \$(EPICS_BASE)/../modules/asyn
EOF
}
	
create_DRIVERS_RELEASE_LIBS_local()
{
  file=$1 &&
	echo PWD=$PWD file=$file &&
	cat >$file <<EOF
ASYN        = \$(EPICS_BASE)/../modules/asyn
AXIS        = \$(EPICS_BASE)/../modules/axis
EOF
}
	

create_soft_x_y() {
  dir=$1
  src=$2
  dst=$3
  echo dir=$dir create_soft_x_y "$@"
  export dir src dst
  (
    cd "$dir" &&
    linkdst=$(readlink $dst) || linkdst=""
    if ! test "$linkdst" || test "$linkdst" != "$src"; then
      # unlink, first as user, then as SUDO
      if test "$linkdst" != "$src"; then
        echo "$linkdst" != "$dst" &&
        echo PWD=$PWD $RM $dst &&
        $RM -f $dst &&
        echo PWD=$PWD $LN -s $src $dst &&
        $LN -s $src $dst || {
          echo >&2 can not link $src $dst
          exit 1
        }
      fi
    fi
  )
}


########################
if ! test -d $EPICS_ROOT; then
  echo $MKDIR -p $EPICS_ROOT &&
  $MKDIR -p $EPICS_ROOT || {
    echo >&2 can not $MKDIR $EPICS_ROOT
    exit 1
  }
fi

if ! test -w $EPICS_ROOT; then
  echo FSUDO=$FSUDO
  echo $FSUDO chown "$USER" $EPICS_ROOT &&
  $FSUDO chown "$USER" $EPICS_ROOT || {
    echo >&2 can not chown $EPICS_ROOT
    exit 1
  }
else
  echo FSUDO=
  export FSUDO
fi
echo FSUDO=$FSUDO

if ! test -d /usr/local; then
  sudo $MKDIR /usr/local
fi &&
create_soft_x_y $EPICS_ROOT base-${EPICS_BASE_VER} base &&


wget_or_curl()
{
  url=$1
  file=$2
  if test -e $file; then
    return;
  fi
  (
    echo cd $EPICS_DOWNLOAD &&
    cd $EPICS_DOWNLOAD &&
    if ! test -e $file; then
        if type curl >/dev/null 2>/dev/null; then
            curl "$url" >/tmp/"$file.$$.tmp" &&
              $MV "/tmp/$file.$$.tmp" "$file" || {
                echo >&2 curl can not get $url
                exit 1
              }
        else
          # We need wget
          if ! type wget >/dev/null 2>/dev/null; then
              echo $APTGET wget
              $APTGET wget
          fi &&
            wget "$url" -O "$file.$$.tmp" &&
            $MV "$file.$$.tmp" "$file" || {
              echo >&2 wget can not get $url
              exit 1
            }
        fi
      fi
  ) &&
  $LN -s $EPICS_DOWNLOAD/$file $file
}

#add package x when y is not there
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

install_asyn_ver()
{
  echo install_axis_from_synapps
  asyndir="$1"/
  cd $EPICS_ROOT/modules &&
  if test -L asyn; then
    echo $RM asyn &&
    $RM asyn
  fi &&
  test -d $asyndir || {
    echo >&2 PWD=$PWD Can not $LN -sv $asyndir asyn
    exit 1
  }
  $LN -sv $asyndir asyn || {
    echo >&2 Can not $LN -sv $asyndir asyn
    exit 1
  }
}

install_axis_X_Y ()
{
  echo install_axis_X_Y
	. $EPICS_ROOT/.epics.$EPICS_HOST_ARCH || {
		echo >&2 "can include $EPICS_ROOT/.epics.$EPICS_HOST_ARCH"
		exit 1
	}
  create_soft_x_y $EPICS_ROOT/modules ../axis/ axis
  (
    cd $EPICS_ROOT &&
      if ! test -d axis; then
				(
					$FSUDO git clone --recursive --branch $AXIS_GIT_VER https://github.com/EPICS-motor-wg/axis.git axis
				)||
          ( $RM -rf axis; false )
      fi
  ) &&
	(
    cd $EPICS_ROOT/axis/configure && {
			create_AXIS_RELEASE_PATH_local RELEASE_PATHS.local &&
			create_AXIS_RELEASE_LIBS_local RELEASE_LIBS.local
    }
  ) &&
  (
    echo run_make_in_dir $EPICS_ROOT/$AXIS_VER_X_Y &&
      run_make_in_dir $EPICS_ROOT/modules/axis &&
      echo done run_make_in_dir $EPICS_ROOT/$AXIS_VER_X_Y
  ) &&
	(
		for d in $EPICS_ROOT/axis/drivers/*; do
			(
				cd "$d" &&
					(
						echo SUB PWD=$PWD &&
						cd configure &&
						create_AXIS_RELEASE_PATH_local RELEASE_PATHS.local &&
						create_DRIVERS_RELEASE_LIBS_local RELEASE_LIBS.local
					)  &&
				make 
			)
		done
	)|| {
    echo >&2 failed $AXIS_VER_X_Y
    exit 1
  }
}

install_streamdevice()
{
  cd $EPICS_ROOT/modules &&
  if ! test -d streamdevice; then
    $MKDIR -p streamdevice
  fi &&
  cd streamdevice &&
  streamdevver=$(echo ../../$SYNAPPS_VER_X_Y/support/stream-*) &&
  echo streamdevver=$streamdevver &&
  if test -L src; then
    echo $RM src &&
    $RM src
  fi &&
  echo $LN -s ../../$SYNAPPS_VER_X_Y/support/$streamdevver/streamDevice/src/ src &&
  $LN -s ../../$SYNAPPS_VER_X_Y/support/$streamdevver/streamDevice/src/ src || exit 1
  for f in dbd lib include; do
    if test -L $f; then
      echo $RM $f &&
      $RM $f
    fi &&
    $LN -s ../../$SYNAPPS_VER_X_Y/support/$streamdevver/$f/ $f || exit 1
  done
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
    case $PWD in
      *3.14.12.3*|*3.14.12.5*|*3.15.1*|*3.15.2*)
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



fix_epics_base()
{
  file="$1" &&
  if test -e "$file"; then
    filebasename="${file%*.original}" &&
    echo fix_epics_base PWD=$PWD file=$file filebasename=$filebasename &&
    if ! test -f "$filebasename.original"; then
      $CP "$file" "$filebasename.original" || {
        echo >&2 failed $CP -v $file $filebasename.original in $PWD
        exit 1
      }
    fi &&
    sed <"$filebasename.original" >/tmp/$$.tmp \
      -e "s!^SUPPORT=.*!SUPPORT=$EPICS_ROOT/base/../support!" \
      -e "s!^EPICS_BASE=.*!EPICS_BASE=$EPICS_ROOT/base!" \
      -e "s!^\(IPAC=.*\)!## rem by install-epics \1!" \
      -e "s!^BUSY=.*!BUSY=\$(SUPPORT)/busy-1-6!" \
      -e "s!^\(SNCSEQ=.*\)!## rem by install-epics \1!"
      $MV -fv /tmp/$$.tmp "$file" &&
      if test "$ASYN_VER_X_Y"; then
        sed <"$file" >/tmp/$$.tmp \
          -e "s!^ASYN=.*!ASYN=$EPICS_MODULES/asyn!" &&
        $MV -fv /tmp/$$.tmp "$file"
    fi
  else
    echo fix_epics_base PWD=$PWD file=$file does not exist, doing nothing
  fi
}

remove_modules_from_RELEASE()
{
  file="$1" &&
  for mod in $MODSTOBEREMOVED; do
    echo removing $mod in $PWD/$file &&
    if grep $mod $file >/dev/null; then
      sed -e "s/\($mod=.*\$\)/## xx \1/g" <$file >$file.$$.tmp &&
      ! diff $file $file.$$.tmp >/dev/null &&
      $MV -f $file.$$.tmp $file || {
        echo >&2 failed removing $mod in $PWD
        exit 1
      }
    fi
  done
}

remove_modules_from_Makefile()
{
  file="$1" &&
  for mod in $MODSTOBEREMOVED; do
    echo removing $mod in $PWD/$file &&
    sed -e "s/ $mod / /g" -e "s/ $mod\$/ /g" <$file >$file.$$.tmp &&
    ! diff $file $file.$$.tmp >/dev/null &&
    $MV -f $file.$$.tmp $file || {
      echo >&2 failed removing $mod in $PWD
      exit 1
    }
  done
}

comment_out_in_file()
{
  suffix=$$
  file=$1 &&
  shift &&
  if ! test -f "$filebasename.original"; then
    $CP "$file" "$filebasename.original" || {
      echo >&2 failed $CP -v $file $filebasename.original in $PWD
      exit 1
    }
  fi &&
  $CP "$filebasename.original" "$file" &&
  for mod in "$@"; do
    if grep "^#.*$mod" $file >/dev/null; then
      echo already commented out $mod in $PWD/$file
    else
      echo commenting out $mod in $PWD/$file &&
      filebasename="${file%*.original}" &&
      echo file=$file filebasename=$filebasename &&
      sed -e "s/\(.*$mod.*\)/# rem by install-epics \1/g" <$file >/tmp/xx.$$ &&
      ! diff  $file $file.suffix >/dev/null &&
      $MV -f /tmp/xx.$$ $file
    fi
  done
}
cd $EPICS_ROOT &&
if ! test -d base-$EPICS_BASE_VER; then
  git clone https://github.com/epics-base/epics-base.git base-$EPICS_BASE_VER &&
  (
    cd base-$EPICS_BASE_VER && git checkout $EPICS_BASE_GIT_VER
  )
fi  &&
(
  case "$EPICS_BASE_VER" in
    3.15.1|3.15.2)
    (
      # Don't build the perl bindings, compile error under Centos
      cd base-$EPICS_BASE_VER/src &&
      if ! grep "#DIRS += ca/client/perl" Makefile >/dev/null; then
        cp Makefile Makefile.orig &&
        sed -e "s!DIRS += ca/client/perl!#DIRS += ca/client/perl!" <Makefile.orig >Makefile
      fi
    )
    ;;
    *)
    ;;
  esac
) || exit 1

#Need to set the softlink now

if test -n "$EPICS_HOST_ARCH"; then
EPICS_HOST_ARCH=$($EPICS_ROOT/base-${EPICS_BASE_VER}/startup/EpicsHostArch) || {
  echo >&2 EPICS_HOST_ARCH failed
  exit 1
}
fi
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
#update .epics
cat >${BASH_ALIAS_EPICS} <<EOF &&
export EPICS_DEBUG=$EPICS_DEBUG
export EPICS_DOWNLOAD=$EPICS_DOWNLOAD
export EPICS_ROOT=$EPICS_ROOT
export EPICS_BASE=\$EPICS_ROOT/base
export EPICS_EXT=\${EPICS_ROOT}/extensions
export EPICS_HOST_ARCH=$($EPICS_BASE/startup/EpicsHostArch)
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
export ASYN=\${EPICS_BASE}/asyn
export BUSY=\${SUPPORT}/busy-1-6
EOF

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

#Modules
(
  cd $EPICS_ROOT/ &&
  if ! test -d modules; then
    $MKDIR modules
  fi
) || exit 1



#Streamdevice from PSI
if test -n "$STREAMDEVICEVER"; then
  (
    cd $EPICS_ROOT &&
    if ! test -f $STREAMDEVICEVER.tgz; then
      wget_or_curl http://epics.web.psi.ch/software/streamdevice/$STREAMDEVICEVER.tgz $STREAMDEVICEVER.tgz.$$
    fi
    if ! test -d $STREAMDEVICEVER; then
      tar xzvf $STREAMDEVICEVER.tgz
    fi
    if ! test -d $EPICS_ROOT/$STREAMDEVICEVER/streamdevice-2.6/configure; then
      $MKDIR -p $EPICS_ROOT/$STREAMDEVICEVER/streamdevice-2.6/configure
    fi
    (
      # Create the files (Obs: \EOF != EOF)
      cd $EPICS_ROOT/$STREAMDEVICEVER/streamdevice-2.6/configure &&
      cat >CONFIG <<\EOF &&
#Generated by install-epics.sh
# CONFIG - Load build configuration data
#
# Do not make changes to this file!

# Allow user to override where the build rules come from
RULES = $(EPICS_BASE)

# RELEASE files point to other application tops
include $(TOP)/configure/RELEASE
-include $(TOP)/configure/RELEASE.$(EPICS_HOST_ARCH).Common
ifdef T_A
-include $(TOP)/configure/RELEASE.Common.$(T_A)
-include $(TOP)/configure/RELEASE.$(EPICS_HOST_ARCH).$(T_A)
endif
CONFIG = $(RULES)/configure
include $(CONFIG)/CONFIG
# Override the Base definition:
INSTALL_LOCATION = $(TOP)
# CONFIG_SITE files contain other build configuration settings
include $(TOP)/configure/CONFIG_SITE
-include $(TOP)/configure/CONFIG_SITE.$(EPICS_HOST_ARCH).Common
ifdef T_A
 -include $(TOP)/configure/CONFIG_SITE.Common.$(T_A)
 -include $(TOP)/configure/CONFIG_SITE.$(EPICS_HOST_ARCH).$(T_A)
endif
EOF

      cat >CONFIG_SITE <<\EOF &&
#Generated by install-epics.sh
CHECK_RELEASE = YES
EOF

      cat >Makefile <<\EOF &&
#Generated by install-epics.sh
TOP=..
include $(TOP)/configure/CONFIG
TARGETS = $(CONFIG_TARGETS)
CONFIGS += $(subst ../,,$(wildcard $(CONFIG_INSTALLS)))
include $(TOP)/configure/RULES
EOF

      cat >RELEASE <<\EOF &&
#Generated by install-epics.sh
TEMPLATE_TOP=$(EPICS_BASE)/templates/makeBaseApp/top
ASYN=${EPICS_ROOT}/modules/asyn
EPICS_BASE=${EPICS_ROOT}/base
EOF

      cat >RULES <<\EOF &&
#Generated by install-epics.sh
# RULES
include $(CONFIG)/RULES
# Library should be rebuilt because LIBOBJS may have changed.
$(LIBNAME): ../Makefile
EOF

      cat >RULES.ioc <<\EOF &&
#Generated by install-epics.sh
#RULES.ioc
include $(CONFIG)/RULES.ioc
EOF

      cat >RULES_DIRS <<\EOF &&
#Generated by install-epics.sh
#RULES_DIRS
include $(CONFIG)/RULES_DIRS
EOF

      cat >RULES_DIRS <<\EOF
#Generated by install-epics.sh
#RULES_TOP
include $(CONFIG)/RULES_TOP
EOF
    )
  )
fi


if test -n "$ASYN_VER_X_Y"; then
(
  create_soft_x_y $EPICS_ROOT/modules ../$ASYN_VER_X_Y/ asyn
    (
      #Note1: asyn should be under modules/
      cd $EPICS_ROOT &&
        if ! test -d $ASYN_VER_X_Y; then
					(
						$FSUDO git clone https://github.com/epics-modules/asyn.git $ASYN_VER_X_Y
						cd $ASYN_VER_X_Y &&
						$FSUDO git checkout $ASYN_GIT_VER
					) ||
             ( $RM -rf $ASYN_VER_X_Y; false )
        fi
    ) &&
    (
      cd $EPICS_ROOT/$ASYN_VER_X_Y/configure && {
        for f in $(find . -name "RELEASE*" ); do
          echo f=$f
          fix_epics_base $f
        done
      }
    ) &&
    (
      run_make_in_dir $EPICS_ROOT/$ASYN_VER_X_Y
    ) || {
      echo >&2 failed $ASYN_VER_X_Y
      exit 1
    }
)
else
  echo no special ASYN_VER_X_Y defined
fi


if test -z "$ASYN_VER_X_Y"; then
  run_make_in_dir $EPICS_ROOT/$SYNAPPS_VER_X_Y/support/asyn-*/asyn
fi &&

install_axis_X_Y &&
install_streamdevice &&
echo install $EPICS_ROOT OK || {
  echo >&2 failed install_streamdevice PWD=$PWD
  exit 1
}

