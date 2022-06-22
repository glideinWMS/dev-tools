#!/usr/bin/env bash


# Stop frontend
/bin/systemctl stop gwms-frontend


# Update Git
sudo yum install \
https://repo.ius.io/ius-release-el7.rpm \
https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm

sudo yum remove git

sudo yum -y install  git236


# Exclude GlideinWMS packages from yum updates
echo "exclude=glidein* condor*" >> /etc/yum.conf


# Check Python version
if [ -z "$MYPYTHON" ]
then
    echo 'Please, define $MYPYTHON environment variable.'
    exit 1
fi


# Clone GlideinWMS
mkdir /opt/gwms-git
cd /opt/gwms-git
git clone ssh://p-glideinwms@cdcvs.fnal.gov/cvs/projects/glideinwms

if [ $(echo "$MYPYTHON" | cut -d "." -f 1) == "python3" ]
then
    pushd glideinwms
    git checkout branch_v3_9
    popd
fi


# Link GlideinWMS repository
cd /usr/lib/$MYPYTHON/site-packages/
mv glideinwms/ fromrpm_glideinwms
ln -s /opt/gwms-git/glideinwms glideinwms

cd /var/lib/gwms-frontend
mkdir fromrpm
mv creation web-base fromrpm/
ln -s /usr/lib/$MYPYTHON/site-packages/glideinwms/creation creation
ln -s /usr/lib/$MYPYTHON/site-packages/glideinwms/creation/web_base web-base

cd /usr/sbin
mkdir -p /opt/fromrpm/usr_sbin

for i in \
checkFrontend glideinFrontend stopFrontend
do
    mv $i /opt/fromrpm/usr_sbin/
    ln -s /usr/lib/$MYPYTHON/site-packages/glideinwms/frontend/${i}.py $i
done

for i in \
glideinFrontendElement.py manageFrontendDowntimes.py
do
    mv $i /opt/fromrpm/usr_sbin/
    ln -s /usr/lib/$MYPYTHON/site-packages/glideinwms/frontend/$i $i
done

for i in \
reconfig_frontend
do
    mv ${i} /opt/fromrpm/usr_sbin
    ln -s /usr/lib/$MYPYTHON/site-packages/glideinwms/creation/$i $i
done

for i in \
glidecondor_createSecCol glidecondor_addDN glidecondor_createSecSched
do
    mv ${i} /opt/fromrpm/usr_sbin
    ln -s /usr/lib/$MYPYTHON/site-packages/glideinwms/install/$i $i
done

cd /usr/bin/
mkdir -p /opt/fromrpm/usr_bin

mv /usr/bin/glidein* /opt/fromrpm/usr_bin/

for i in \
glidein_cat glidein_gdb glidein_interactive glidein_ls glidein_ps \
glidein_status glidein_top
do
    ln -s /usr/lib/$MYPYTHON/site-packages/glideinwms/tools/${i}.py $i
done


# Start frontend
/usr/sbin/gwms-frontend upgrade
/bin/systemctl start gwms-frontend