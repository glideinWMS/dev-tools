#!/bin/bash

usage() {
  cat << EOF
$0 [options]
Print GlideinWMS software info (installed sw, related hosts, ...)
Options:
 -h	print this message
 -r	print also RPM packages available in various yum repositories
EOF
}

# Process options
[[ "$1" = "-h" ]] && { usage; exit 0; }

onliner=$(hostname)

########
# TODO: functions finding components from configuration and condor status, not mapfile that will be unreliable after x509 is gone

findce() {
  # find CEs in Factory configuration (entries) or condor_status
}

findfe() {
  # find Frontends in the factory condor status
}

findfa() {
  # find Factories in the configuration (or factory condor status?)
}

findde() {
  # find DE in the Factory condor status
}

# What is installed?
isfactory=false
isfrontend=false
isdecisionengine=false
iscondor=false
iscondorce=false

if [[ -e /etc/gwms-factory ]]; then
  isfactory=true
  faver=$(yum list installed glideinwms-factory | grep factory | xargs echo | cut -d ' ' -f 2)
  echo "Found GWMS Factory (/etc/gwms-factory), version $faver"
fi
if [[ -e /etc/gwms-frontend ]]; then
  isfrontend=true
  fever=$(yum list installed glideinwms-vofrontend | grep vofrontend | xargs echo | cut -d ' ' -f 2)
  echo "Found GWMS VO Frontend (/etc/gwms-frontend), version $fever"
fi
[[ -e /etc/condor ]] && { iscondor=true; echo "Found HTCondor (/etc/condor), version $(rpm -q condor)"; }
[[ -e /etc/condor-ce ]] && { iscondorce=true; echo "Found HTCondor-CE (/etc/condor-ce), version $(rpm -q htcondor-ce)"; }
if [[ -e /etc/decisionengine ]]; then
  isdecisionengine=true
  dever=$(yum list installed decisionengine | grep decisionengine | xargs echo | cut -d ' ' -f 2)
  echo "Found DE (/etc/decisionengine), version $dever"
fi

if ! $isfactory && ! $isfrontend; then
  echo "No GWMS Factory or Frontend found"
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
echo "Calculating available RPMs ..."
gvers=$(yum list --enablerepo=osg-upcoming,osg-upcoming-development,osg-development,osg-contrib --show-duplicates available glideinwms-libs)
cat << EOF
- osg (productions): $(echo "$gvers" | grep "osg " | tail -n 1 | xargs echo | cut -d ' ' -f2)
- osg-development: $(echo "$gvers" | grep "osg-development" | xargs echo | cut -d ' ' -f2)
- osg-upcoming: $(echo "$gvers" | grep "osg-upcoming" | xargs echo | cut -d ' ' -f2)
- osg-upcoming-development: $(echo "$gvers" | grep "osg-upcoming-development" | xargs echo | cut -d ' ' -f2)
- osg-contrib: $(echo "$gvers" | grep "osg-contrib" | xargs echo | cut -d ' ' -f2)
EOF

