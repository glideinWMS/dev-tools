#!/bin/bash
BASEDIR=/opt/oldlog
SOURCEDIR=$HOME/bin

mydate="$(date +"%Y%m%d-%H%M%S-%s")"
function clean_condor {
  condor_dir="$BASEDIR/condor-$mydate"
  mkdir "$condor_dir"
  pushd /var/log/condor > /dev/null || return 1
  mv ./*Log* KernelTuning.log "$condor_dir"/
  echo "Logs moved to $condor_dir"
  popd > /dev/null || return 1
}

function clean_gwms_fe {
  gwms_dir="$BASEDIR/gwms-$mydate"
  mkdir "$gwms_dir"
  pushd /var/log/gwms-frontend > /dev/null || return 1
  mv frontend/frontend*.log* "$gwms_dir/"
  mv frontend/startup.log "$gwms_dir/"
  for i in group_*; do 
      mv "$i/${i:6}"*.log* "$gwms_dir/"
  done
  echo "Logs moved to $gwms_dir"
  popd > /dev/null || return 1
}

function clean_gwms_fa {
  # counting on entry names being unique (and not facory* or group*)
  # client logs not moved: job stdout/err and condor logs
  gwms_dir="$BASEDIR/gwms-$mydate"
  mkdir "$gwms_dir"
  pushd /var/log/gwms-factory > /dev/null || return 1
  mv server/factory/factory*.log* "$gwms_dir/"
  mv server/factory/group*.log* "$gwms_dir/"
  for i in server/entry_*; do 
      j="$(basename $i)"
      mv "$i/${j:6}"*.log* "$gwms_dir/"
  done
  echo "Logs moved to $gwms_dir"
  if [ -n MV_CLIENT ]; then
    for i in client/*; do
      pushd "$i" || return 1
      for j in *; do 
        pushd "$j" || return 1
        for k in entry_*; do
          mkdir "$gwms_dir/client_${i}_${j}_${k}"
          mv "$k"/* "$gwms_dir/client_${i}_${j}_${k}/"
        done
        popd > /dev/null || return 1
      done
      popd > /dev/null || return 1
    done
    echo "Client logs moved to $gwms_dir"
  fi
  popd > /dev/null || return 1
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
  systemctl stop gwms-frontend
fi

if [ -e /etc/gwms-factory/glideinWMS.xml ]; then
  echo "Stopping factory"
  systemctl stop gwms-factory
fi

# HTCondor
echo "Cleaning HTCondor"
systemctl stop condor
[ -n "$NODEBUG" ] && echo "Unset HTCondor debug" && rm /etc/condor/config.d/99_debug.config
if [ -n "$SETDEBUG" ]; then
  echo "Enable HTCondor debug"
  if [ -r "$SOURCEDIR"/99_debug.config ]; then
    cp "$SOURCEDIR"/99_debug.config /etc/condor/config.d/99_debug.config
  else
    cat << EOF > /etc/condor/config.d/99_debug.config
ALL_DEBUG = D_FULLDEBUG D_SECURITY
EOF
  fi
fi
if ! clean_condor; then
  echo "FAILED to clean HTCondor"
fi
systemctl start condor

# To le condor restart and avoid errors
echo "Waiting for condor to start"
sleep 10
condor_status -any

# GWMS
if [ -e /etc/gwms-frontend/frontend.xml ]; then
  echo "Cleaning Frontend"
  if ! clean_gwms_fe; then
    echo "FAILED to clean Frontend"
  fi
  systemctl start gwms-frontend
fi

if [ -e /etc/gwms-factory/glideinWMS.xml ]; then
  echo "Cleaning Factory"
  if ! clean_gwms_fa; then
    echo "FAILED to clean Factory"
  fi
  systemctl start gwms-factory
fi





