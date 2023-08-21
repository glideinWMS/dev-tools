#!/usr/bin/env bash


### INTRO ###

# Environment
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
FACTORY_HOST=$(hostname)
FACTORY_XML=/etc/gwms-factory/glideinWMS.xml
FACTORY_XML_TEMPLATE="$DIR"/Templates/glideinWMS.xml
FACTORY_MAPFILE=/etc/condor/certs/condor_mapfile
FACTORY_MAPFILE_TEMPLATE="$DIR"/Templates/factory_condor_mapfile
TOKEN_DIR=/var/lib/gwms-factory/.condor/tokens.d
CONDOR_TARBALL_PATH=/var/lib/gwms-factory/condor
OSG_REPO=osg
FACTORY_REPO=osg-development
OSG_VERSION=3.6
OS_VERSION=9
EXTRA_REPOS=

CONDOR_TARBALL_URLS='
https://research.cs.wisc.edu/htcondor/tarball/9.0/9.0.17/release/condor-9.0.17-x86_64_CentOS7-stripped.tar.gz
'

# Argument parser
while [ -n "$1" ];do
    case "$1" in
        --osgrepo)
            OSG_REPO="$2"
            shift
            ;;
        --factoryrepo)
            FACTORY_REPO="$2"
            shift
            ;;
        --frontend)
            FRONTEND_HOST="$2"
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

if [ -z "$FRONTEND_HOST" ]; then
    echo "Frontend hostname was not provided."
    echo "Please inform it with '--frontend [HOSTNAME]'."
    exit 2
fi

# Export variables
export FACTORY_HOST
export FRONTEND_HOST


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
yum install "$Y" osg-ca-certs "$EXTRA_REPOS" --enablerepo="$OSG_REPO"

# HTCondor
if [ "$OS_VERSION" -gt 7 ]; then
    yum install "$Y" condor.x86_64 "$EXTRA_REPOS" --enablerepo="$OSG_REPO"
else
    yum install "$Y" https://research.cs.wisc.edu/htcondor/repo/9.0/htcondor-release-current.el7.noarch.rpm
    yum install "$Y" condor --disablerepo=osg*
fi

# Factory
yum install "$Y" glideinwms-factory "$EXTRA_REPOS" --enablerepo="$FACTORY_REPO"


### CONFIGURATION ###

# glideinWMS.xml
rm -f $FACTORY_XML
envsubst < "$FACTORY_XML_TEMPLATE" > "/tmp/glideinWMS.xml"
mv "/tmp/glideinWMS.xml" "$FACTORY_XML"
chown gfactory.gfactory "$FACTORY_XML"
echo Updated "$FACTORY_XML"

# condor_mapfile
rm -f $FACTORY_MAPFILE
envsubst < "$FACTORY_MAPFILE_TEMPLATE" > "/tmp/condor_mapfile"
mv "/tmp/condor_mapfile" "$FACTORY_MAPFILE"
echo Updated "$FACTORY_MAPFILE"

# Tokens
echo Creating IDTOKENS...
mkdir -p "$TOKEN_DIR"
condor_store_cred -c add -p glideinwms-pass-$RANDOM
condor_token_create -id gfactory@"$HOSTNAME" > "$TOKEN_DIR"/gfactory."$HOSTNAME".idtoken
chown -R gfactory:gfactory "$TOKEN_DIR"
chmod 600 "$TOKEN_DIR"/*
condor_token_create -id vofrontend_service@"$HOSTNAME" -key POOL > ~/frontend."$HOSTNAME".idtoken
ls -lah "$TOKEN_DIR"

# Condor tarball
[ ! -d $CONDOR_TARBALL_PATH ] && mkdir -p $CONDOR_TARBALL_PATH
pushd $CONDOR_TARBALL_PATH || exit 3
for CONDOR_TARBALL_URL in $CONDOR_TARBALL_URLS; do
    wget "$CONDOR_TARBALL_URL"
    CONDOR_TARBALL=$(echo "$CONDOR_TARBALL_URL" | awk -F'/' '{print $NF}')
    tar -xf "$CONDOR_TARBALL" && rm -f "$CONDOR_TARBALL"
done
popd || exit 4

# Update factory configuration
gwms-factory upgrade


### START SERVICES ###

#httpd
systemctl enable httpd
systemctl start httpd

#condor
systemctl enable condor
systemctl start condor

#gwms-factory
systemctl enable gwms-factory
systemctl start gwms-factory

#fetch-crl
systemctl enable fetch-crl-boot
