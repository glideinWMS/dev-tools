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
PROXY_DIR=/proxy
TOKEN_DIR=/var/lib/gwms-frontend/.condor/tokens.d
VOFE_PROXY="$PROXY_DIR"/vofe_proxy
PILOT_PROXY="$PROXY_DIR"/pilot_proxy
OSG_REPO=osg
FRONTEND_REPO=osg

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
        --osg36)
            OSG_3_6="1"
            ;;
        --el8)
            EL8="1"
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
export TOKEN_DIR


### REPOSITORIES ###

# EPEL Repo
if [ -z "$EL8" ]; then
    yum install $Y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
fi

# OSG Repo
if [ -z "$OSG_3_6" ]; then
    OSG_VERSION=3.5
else
    OSG_VERSION=3.6
fi
if [ -z "$EL8" ]; then
    EL_VERSION=el7
else
    EL_VERSION=el8
fi
yum install $Y https://repo.opensciencegrid.org/osg/"$OSG_VERSION"/osg-"$OSG_VERSION"-"$EL_VERSION"-release-latest.rpm
sed -i "s/priority=[0-9]*/priority=1/g" /etc/yum.repos.d/osg*


### INSTALLATION ###

# OSG
yum install $Y osg-ca-certs

# Token Tools
yum install $Y htgettoken

# HTCondor
yum install $Y condor.x86_64 --enablerepo="$OSG_REPO"

# Frontend
yum install $Y glideinwms-vofrontend --enablerepo="$FRONTEND_REPO"


### CONFIGURATION ###

# frontend.xml
mv $FRONTEND_XML $FRONTEND_XML.bak
envsubst < "$FRONTEND_XML_TEMPLATE" > "/tmp/frontend.xml"
mv "/tmp/frontend.xml" "$FRONTEND_XML"
chown frontend.frontend "$FRONTEND_XML"
echo Updated "$FRONTEND_XML"

# condor_mapfile
mv $FRONTEND_MAPFILE $FRONTEND_MAPFILE.bak
envsubst < "$FRONTEND_MAPFILE_TEMPLATE" > "/tmp/condor_mapfile"
mv "/tmp/condor_mapfile" "$FRONTEND_MAPFILE"
echo Updated "$FRONTEND_MAPFILE"

# Proxies
echo Creating proxies...
mkdir -p "$PROXY_DIR"
voms-proxy-init -valid 900:00 -cert /etc/grid-security/hostcert.pem -key /etc/grid-security/hostkey.pem -out "$VOFE_PROXY"
voms-proxy-init -debug -valid 900:00 -cert "$CERT" -key "$KEY" -out "$PILOT_PROXY" -voms fermilab
chown frontend.frontend "$VOFE_PROXY"
chown frontend.frontend "$PILOT_PROXY"
ls -lah "$VOFE_PROXY"
ls -lah "$PILOT_PROXY"

# Tokens
echo Creating IDTOKENS...
systemctl start condor
sleep 5
mkdir -p "$TOKEN_DIR"
condor_token_create -id vofrontend_service@"$HOSTNAME" -key POOL > "$TOKEN_DIR"/frontend."$HOSTNAME".idtoken
scp root@"$FACTORY_HOST":/root/frontend."$FACTORY_HOST".idtoken  "$TOKEN_DIR"/frontend."$FACTORY_HOST".idtoken
chown -R frontend:frontend "$TOKEN_DIR"
chmod 600 "$TOKEN_DIR"/*
ls -lah "$TOKEN_DIR"
systemctl stop condor
echo Generating SciToken...
htgettoken --minsecs=3580 -i fermilab -v -a fermicloud543.fnal.gov -o "$TOKEN_DIR"/"$HOSTNAME".scitoken

# Update frontend configuration
gwms-frontend upgrade
gwms-frontend reconfig


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
