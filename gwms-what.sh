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

# What is installed?
isfactory=false
isfrontend=false
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
[[ -e /etc/condor ]] && { iscondor=true; echo "Found HTCondor (/etc/condor)"; }
[[ -e /etc/condor-se ]] && { iscondorce=true; echo "Found HTCondor-CE (/etc/condor-ce)"; }

if ! $isfactory && ! $isfrontend; then
  echo "No GWMS Factory or Frontend found"
  exit
fi

fehost=$(grep vofrontend /etc/condor/certs/condor_mapfile | grep -v Mambelli)
fehost=${fehost##*=}
fehost=${fehost%\$*}
fahost=$(grep factory /etc/condor/certs/condor_mapfile)
fahost=${fahost##*=}
fahost=${fahost%\$*}

cat << EOF
Setup:
- this host: $(hostname)
- Factory: $fahost $($isfactory && echo "(this)")
- Frontend: $fehost $($isfrontend && echo "(this)")
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

