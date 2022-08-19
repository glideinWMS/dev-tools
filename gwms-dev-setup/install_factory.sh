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
CONDOR_TARBALL_VERSION=9.0.0
CONDOR_TARBALL_PATH=/var/lib/gwms-factory/condor
OSG_REPO=osg
FACTORY_REPO=osg
EXTRA_REPOS=

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

if [ -z "$FRONTEND_HOST" ]; then
    echo "Frontend hostname was not provided."
    echo "Please inform it with '--frontend [HOSTNAME]'."
    exit 2
fi

# Process variables
CONDOR_TARBALL_URL=https://research.cs.wisc.edu/htcondor/tarball/
CONDOR_TARBALL_URL="$CONDOR_TARBALL_URL"$(echo "$CONDOR_TARBALL_VERSION" | cut -d . -f 1,2)/
CONDOR_TARBALL_URL="$CONDOR_TARBALL_URL""$CONDOR_TARBALL_VERSION"/release/
CONDOR_TARBALL_URL="$CONDOR_TARBALL_URL"condor-"$CONDOR_TARBALL_VERSION"-x86_64_CentOS7-stripped.tar.gz
CONDOR_TARBALL_DIR=condor-"$CONDOR_TARBALL_VERSION"
if [ "$(echo $CONDOR_TARBALL_VERSION | cut -d '.' -f 1)" -ge "9" ]; then
    CONDOR_TARBALL_DIR="$CONDOR_TARBALL_DIR"-1
fi
CONDOR_TARBALL_DIR="$CONDOR_TARBALL_DIR"-x86_64_CentOS7-stripped
CONDOR_TARBALL=condor-"$CONDOR_TARBALL_VERSION"-x86_64_CentOS7-stripped
export FACTORY_HOST
export FRONTEND_HOST
export CONDOR_TARBALL
export CONDOR_TARBALL_DIR
export CONDOR_TARBALL_PATH
export CONDOR_TARBALL_VERSION


### REPOSITORIES ###

# EPEL Repo
if [ -z "$EL8" ]; then
    yum install $Y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
else
    # Alma8 requires powertools (alma8-powertools)
    EXTRA_REPOS="$EXTRA_REPOS --enablerepo=powertools"
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
yum install $Y osg-ca-certs $EXTRA_REPOS --enablerepo="$OSG_REPO"

# HTCondor
yum install $Y condor.x86_64 $EXTRA_REPOS --enablerepo="$OSG_REPO" 

# Factory
yum install $Y glideinwms-factory $EXTRA_REPOS --enablerepo="$FACTORY_REPO"


### CONFIGURATION ###

# glideinWMS.xml
mv $FACTORY_XML $FACTORY_XML.bak
envsubst < "$FACTORY_XML_TEMPLATE" > "/tmp/glideinWMS.xml"
mv "/tmp/glideinWMS.xml" "$FACTORY_XML"
chown gfactory.gfactory "$FACTORY_XML"
echo Updated "$FACTORY_XML"

# condor_mapfile
mv $FACTORY_MAPFILE $FACTORY_MAPFILE.bak
envsubst < "$FACTORY_MAPFILE_TEMPLATE" > "/tmp/condor_mapfile"
mv "/tmp/condor_mapfile" "$FACTORY_MAPFILE"
echo Updated "$FACTORY_MAPFILE"

# Tokens
echo Creating IDTOKENS...
systemctl start condor
sleep 5
mkdir -p "$TOKEN_DIR"
condor_token_create -id gfactory@"$HOSTNAME" > "$TOKEN_DIR"/gfactory."$HOSTNAME".idtoken
chown -R gfactory:gfactory "$TOKEN_DIR"
chmod 600 "$TOKEN_DIR"/*
condor_token_create -id vofrontend_service@"$HOSTNAME" -key POOL > ~/frontend."$HOSTNAME".idtoken
ls -lah "$TOKEN_DIR"
systemctl stop condor

# Condor tarball
[ ! -d $CONDOR_TARBALL_PATH ] && mkdir -p $CONDOR_TARBALL_PATH
pushd $CONDOR_TARBALL_PATH || exit 3
wget "$CONDOR_TARBALL_URL"
tar -xf "$CONDOR_TARBALL".tar.gz && rm "$CONDOR_TARBALL".tar.gz
popd || exit 4

# Update factory configuration
gwms-factory upgrade
gwms-factory reconfig


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
