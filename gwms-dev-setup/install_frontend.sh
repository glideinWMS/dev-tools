#!/usr/bin/env bash


### INTRO ###

# Environment
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
FRONTEND_HOST=$(hostname)
FRONTEND_NAME=$(hostname -s)
FRONTEND_XML=/etc/gwms-frontend/frontend.xml
FRONTEND_XML_TEMPLATE="$DIR"/Templates/frontend.xml
FRONTEND_MAPFILE=/etc/condor/certs/condor_mapfile
FRONTEND_MAPFILE_TEMPLATE="$DIR"/Templates/frontend_condor_mapfile
CERT="$DIR"/Certificates/usercert.pem
KEY="$DIR"/Certificates/userkey.pem
CRED_DIR=/opt/gwms/credentials
TOKEN_DIR=/var/lib/gwms-frontend/.condor/tokens.d
VOFE_PROXY="$CRED_DIR"/vofe_proxy
PILOT_PROXY="$CRED_DIR"/pilot_proxy
PILOT_SCITOKEN="$CRED_DIR"/pilot.scitoken
OSG_REPO=osg
FRONTEND_REPO=osg-development
OSG_VERSION=3.6
OS_VERSION=9
EXTRA_REPOS=

# Argument parser
while [ -n "$1" ];do
    case "$1" in
        --osgrepo)
            OSG_REPO="$2"
            shift
            ;;
        --frontendrepo)
            FRONTEND_REPO="$2"
            shift
            ;;
        --factory)
            FACTORY_HOST="$2"
            shift
            ;;
        --cert)
            CERT="$2"
            shift
            ;;
        --key)
            KEY="$2"
            shift
            ;;
        --osg-version)
            OSG_VERSION="$2"
            ;;
        --os-version)
            OS_VERSION="$2"
            ;;
        -y)
            Y="-y"
            ;;
        *)
            echo "Parameter '$1' is not supported."
            exit 1
    esac
    shift
done

if [ -z "$FACTORY_HOST" ]; then
    echo "Factory hostname was not provided."
    echo "Please inform it with '--factory [HOSTNAME]'."
    exit 2
fi

# Process variables
PILOT_DN=$(openssl x509 -in "$CERT" -noout -subject | cut -b 10-)
export FRONTEND_HOST
export FRONTEND_NAME
export FACTORY_HOST
export PILOT_DN
export VOFE_PROXY
export PILOT_PROXY
export PILOT_SCITOKEN
export TOKEN_DIR


### REPOSITORIES ###

# EPEL Repo
if [ "$OS_VERSION" -le 7 ]; then
    yum install "$Y" https://dl.fedoraproject.org/pub/epel/epel-release-latest-"$OS_VERSION".noarch.rpm
else
    # Alma8 requires powertools (alma8-powertools)
    EXTRA_REPOS="$EXTRA_REPOS --enablerepo=powertools"
fi

# OSG Repo
yum install "$Y" https://repo.opensciencegrid.org/osg/"$OSG_VERSION"/osg-"$OSG_VERSION"-el"$OS_VERSION"-release-latest.rpm
sed -i "s/priority=[0-9]*/priority=1/g" /etc/yum.repos.d/osg*


### INSTALLATION ###

# OSG
yum install "$Y" osg-ca-certs $EXTRA_REPOS --enablerepo="$OSG_REPO"

# Token Tools
yum install "$Y" htgettoken $EXTRA_REPOS --enablerepo="$OSG_REPO"

# HTCondor
if [ "$OS_VERSION" -gt 7 ]; then
    yum install "$Y" condor.x86_64 "$EXTRA_REPOS" --enablerepo="$OSG_REPO"
else
    yum install "$Y" https://research.cs.wisc.edu/htcondor/repo/9.0/htcondor-release-current.el7.noarch.rpm
    yum install "$Y" condor --disablerepo=osg*
fi

# Frontend
yum remove "$Y" voms
yum install "$Y" glideinwms-vofrontend $EXTRA_REPOS --enablerepo="$FRONTEND_REPO" --disablerepo=slf-primary

# Fermi extra
yum install "$Y" fermilab-util_kx509

### CONFIGURATION ###

# frontend.xml
rm -f $FRONTEND_XML
envsubst < "$FRONTEND_XML_TEMPLATE" > "/tmp/frontend.xml"
mv "/tmp/frontend.xml" "$FRONTEND_XML"
chown frontend.frontend "$FRONTEND_XML"
echo Updated "$FRONTEND_XML"

# condor_mapfile
rm -f $FRONTEND_MAPFILE
envsubst < "$FRONTEND_MAPFILE_TEMPLATE" > "/tmp/condor_mapfile"
mv "/tmp/condor_mapfile" "$FRONTEND_MAPFILE"
echo Updated "$FRONTEND_MAPFILE"

# Proxies
echo Creating proxies...
mkdir -p "$CRED_DIR"
voms-proxy-init -valid 900:00 -cert /etc/grid-security/hostcert.pem -key /etc/grid-security/hostkey.pem -out "$VOFE_PROXY"
voms-proxy-init -debug -valid 900:00 -cert "$CERT" -key "$KEY" -out "$PILOT_PROXY" -voms fermilab
chown frontend.frontend "$VOFE_PROXY"
chown frontend.frontend "$PILOT_PROXY"
ls -lah "$VOFE_PROXY"
ls -lah "$PILOT_PROXY"

# Tokens
echo Creating IDTOKENS...
mkdir -p "$TOKEN_DIR"
condor_store_cred -c add -p $RANDOM
condor_token_create -id vofrontend_service@"$HOSTNAME" -key POOL > "$TOKEN_DIR"/frontend."$HOSTNAME".idtoken
scp root@"$FACTORY_HOST":/root/frontend."$FACTORY_HOST".idtoken  "$TOKEN_DIR"/frontend."$FACTORY_HOST".idtoken
chown -R frontend:frontend "$TOKEN_DIR"
chmod 600 "$TOKEN_DIR"/*
ls -lah "$TOKEN_DIR"
echo Generating SciToken...
mkdir -p "$CRED_DIR"
htgettoken --minsecs=3580 -i fermilab -v -a htvaultprod.fnal.gov -o "$PILOT_SCITOKEN"
chown frontend.frontend "$PILOT_SCITOKEN"
chmod 600 "$PILOT_SCITOKEN"
ls -lah "$PILOT_SCITOKEN"

# Update frontend configuration
gwms-frontend upgrade


### START SERVICES ###

#httpd
systemctl enable httpd
systemctl start httpd

#condor
systemctl enable condor
systemctl start condor

#gwms-frontend
systemctl enable gwms-frontend
systemctl start gwms-frontend

#fetch-crl
systemctl enable fetch-crl-boot
