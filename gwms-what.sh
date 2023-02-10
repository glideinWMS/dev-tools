#!/bin/bash

# script timeout value in seconds (add 1s before SIGKILL) 
SCRIPT_TIMEOUT=15

usage() {
  cat << EOF
$0 [options]
Print GlideinWMS software info (installed sw, related hosts, ...)
Options (only one of):
 -h	print this message
 -n	no timeout
 -r	print also RPM packages available in various yum repositories (no timeout)
EOF
}

# Process options
[[ "$1" = "-h" ]] && { usage; exit 0; }

if [[ "$1" = "-n" ]]; then
  SCRIPT_TIMEOUT=0
  shift
fi

# Script timeout handling and watchdog
_cleanup() {
  echo "gwms-what.sh timed out. Output unavailable."
  exit 1
}

if [[ "$SCRIPT_TIMEOUT" -gt 0 ]]; then

  trap _cleanup SIGTERM

  # Adding 10+1s timeout from http://www.bashcookbook.com/bashinfo/source/bash-4.0/examples/scripts/timeout3
  # kill -0 pid   Exit code indicates if a signal may be sent to $pid process.
  (
    ((t = $SCRIPT_TIMEOUT))

    while ((t > 0)); do
        sleep 1
        kill -0 $$ || exit 0
        ((t -= 1))
    done

    # Be nice, post SIGTERM first, then wait 1 more second.
    # The 'exit 0' below will be executed if any preceeding command fails.
    echo "gwms-what.sh timed out. Output unavailable."
    kill -s SIGTERM $$ && kill -0 $$ || exit 0
    sleep 1
    kill -s SIGKILL $$
  ) 2> /dev/null &

fi


########
# TODO: functions finding components from configuration and condor status, not mapfile that will be unreliable after x509 is gone

findce() {
  true  # find CEs in Factory configuration (entries) or condor_status
}

findfe() {
  true  # find Frontends in the factory condor status
}

findfa() {
  true  # find Factories in the configuration (or factory condor status?)
}

findde() {
  true  # find DE in the Factory condor status
}



# What is installed?
isfactory=false
isfrontend=false
isdecisionengine=false
iscondor=false
iscondorce=false

if [[ -e /etc/gwms-factory ]]; then
  isfactory=true
  faver=$(rpm -q glideinwms-factory)
  faver="${faver#glideinwms-factory-}"
  echo "Found GWMS Factory (/etc/gwms-factory), version $faver"
fi
if [[ -e /etc/gwms-frontend ]]; then
  isfrontend=true
  fever=$(rpm -q glideinwms-vofrontend)
  fever="${fever#glideinwms-vofrontend-}"
  echo "Found GWMS VO Frontend (/etc/gwms-frontend), version $fever"
fi
[[ -e /etc/condor ]] && { iscondor=true; echo "Found HTCondor (/etc/condor), version $(rpm -q condor)"; }
[[ -e /etc/condor-ce ]] && { iscondorce=true; echo "Found HTCondor-CE (/etc/condor-ce), version $(rpm -q htcondor-ce), auth: $(condor_ce_config_val SEC_DEFAULT_AUTHENTICATION_METHODS)"; }
if [[ -e /etc/decisionengine ]]; then
  isdecisionengine=true
  dever=$(rpm -q decisionengine)
  dever="${dever#decisionengine-}"
  echo "Found DE (/etc/decisionengine), version $dever"
fi

if ! $isfactory && ! $isfrontend && ! $isdecisionengine; then
  echo "No DE, GWMS Factory or Frontend found"
  exit
fi

# Use the mapfile to find out the hosts. This is incorrect if hosts certificates are not used (tokens, user certificates, ...)
# Get frontends and remove user IDs (also user certificated are mapped to the frontend user)
fehostlist=$(grep vofrontend /etc/condor/certs/condor_mapfile | grep -v "CN=UID" | grep -v Mambelli)
#fehost=${fehostlist##*=}  # getting the last one
#fehost=${fehost%\$*}
fehosts=$(echo "$fehostlist" | sed -e 's;.*=;;' -e 's;\$.*;;' | sed ':a; N; $!ba; s/\n/, /g')
fahostlist=$(grep factory /etc/condor/certs/condor_mapfile)
#fahost=${fahostlist##*=}   # getting the last one
#fahost=${fahost%\$*}
fahosts=$(echo "$fahostlist" | sed -e 's;.*=;;' -e 's;\$.*;;' | sed ':a; N; $!ba; s/\n/, /g')
dehostlist=$(grep decisionengine /etc/condor/certs/condor_mapfile | grep -v "CN=UID" | grep -v Mambelli)
dehosts=$(echo "$dehostlist" | sed -e 's;.*=;;' -e 's;\$.*;;' | sed ':a; N; $!ba; s/\n/, /g')

cat << EOF
Setup:
- this host: $(hostname)
- Factory$($isfactory && echo "(this)"): $fahosts 
- Frontend$($isfrontend && echo "(this)"): $fehosts 
- DecisionEngine$($isdecisionengine && echo "(this)"): $dehosts 
EOF

# Print RPM versions if requested
[[ "$1" = "-r" ]] || exit 0
echo "Calculating available glideinwms RPMs ..."
gvers=$(yum list --enablerepo=osg-upcoming,osg-upcoming-development,osg-development,osg-contrib --show-duplicates available glideinwms-libs)
cat << EOF
- osg (productions): $(echo "$gvers" | grep "osg " | tail -n 1 | xargs echo | cut -d ' ' -f2)
- osg-development: $(echo "$gvers" | grep "osg-development" | xargs echo | cut -d ' ' -f2)
- osg-upcoming: $(echo "$gvers" | grep "osg-upcoming" | xargs echo | cut -d ' ' -f2)
- osg-upcoming-development: $(echo "$gvers" | grep "osg-upcoming-development" | xargs echo | cut -d ' ' -f2)
- osg-contrib: $(echo "$gvers" | grep "osg-contrib" | xargs echo | cut -d ' ' -f2)
EOF

