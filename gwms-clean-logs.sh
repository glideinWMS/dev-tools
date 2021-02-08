#!/bin/bash
BASEDIR=/opt/oldlog
SOURCEDIR=~marcom/data/glideinwms-autoinstaller/aux/

mydate="`date +"%Y%m%d-%H%M%S-%s"`"
function clean_condor {
  condor_dir="$BASEDIR/condor-$mydate"
  mkdir "$condor_dir"
  pushd /var/log/condor > /dev/null
  mv *Log* KernelTuning.log "$condor_dir"/
  echo "Logs moved to $condor_dir"
  popd > /dev/null
}

function clean_gwms_fe {
  gwms_dir="$BASEDIR/gwms-$mydate"
  mkdir "$gwms_dir"
  pushd /var/log/gwms-frontend > /dev/null
  mv frontend/frontend*.log* "$gwms_dir/"
  mv frontend/startup.log "$gwms_dir/"
  for i in group_*; do 
      mv "$i/${i:6}"*.log* "$gwms_dir/"
  done
  echo "Logs moved to $gwms_dir"
  popd > /dev/null
}

function clean_gwms_fa {
  # counting on entry names being unique (and not facory* or group*)
  # client logs not moved: job stdout/err and condor logs
  gwms_dir="$BASEDIR/gwms-$mydate"
  mkdir "$gwms_dir"
  pushd /var/log/gwms-factory > /dev/null
  mv server/factory/factory*.log* "$gwms_dir/"
  mv server/factory/group*.log* "$gwms_dir/"
  for i in server/entry_*; do 
      j="`basename $i`"
      mv "$i/${j:6}"*.log* "$gwms_dir/"
  done
  echo "Logs moved to $gwms_dir"
  if [ -n MV_CLIENT ]; then
    for i in client/*; do
      pushd "$i"
      for j in *; do 
	pushd "$j"
	for k in entry_*; do
	  mkdir "$gwms_dir/client_$i_$j_$k"
	  mv "$k"/* "$gwms_dir/client_$i_$j_$k/"
	done
	popd > /dev/null
      done
      popd > /dev/null
    done
    echo "Client logs moved to $gwms_dir"
  fi
  popd > /dev/null
}

function print_help {
  cat << EOF 
$0 [options]
Clean (i.e. rotate to old directory) HTCondor and GWMS (frontend or factory) logs
-h 	print this message
-d 	set HTCondor debug
-D 	remove HTCondor debug
-c 	move also Factory client logs (HTCondor and jobs stderr/out)
EOF
}

##### SCRIPT STARTS #######
# Setup

# TODO: use getopt if there are more options
# -h help
# -d set debug (condor)
# -D remove debug (condor)

if [ "$1" = "-h" ]; then
  print_help
  exit 0
fi
 
if [ "$1" = "-d" ]; then
  SETDEBUG=yes
fi
if [ "$1" = "-D" ]; then
  NODEBUG=yes
fi
if [ "$1" = "-c" ]; then
  MV_CLIENT=yes
fi



mkdir -p "$BASEDIR"

# GWMS stop (before cycling HTCondor)
if [ -e /etc/gwms-frontend/frontend.xml ]; then
  echo "Stopping frontend"
  service gwms-frontend stop
fi

if [ -e /etc/gwms-factory/glideinWMS.xml ]; then
  echo "Stopping factory"
  service gwms-factory stop
fi

# HTCondor
echo "Cleaning HTCondor"
service condor stop
[ -n "$NODEBUG" ] && echo "Unset HTCondor debug" && rm /etc/condor/config.d/99_debug.config
[ -n "$SETDEBUG" ] && echo "Enable HTCondor debug" && cp "$SOURCEDIR"/99_debug.config /etc/condor/config.d/99_debug.config
clean_condor
service condor start

# To le condor restart and avoid errors
echo "Waiting for condor to start"
sleep 10
condor_status -any

# GWMS
if [ -e /etc/gwms-frontend/frontend.xml ]; then
  echo "Cleaning frontend"
  clean_gwms_fe
  service gwms-frontend start
fi

if [ -e /etc/gwms-factory/glideinWMS.xml ]; then
  echo "Cleaning factory"
  clean_gwms_fa
  service gwms-factory start
fi





