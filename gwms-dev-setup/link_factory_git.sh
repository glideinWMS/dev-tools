#!/usr/bin/env bash


# Stop factory
/bin/systemctl stop gwms-factory


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
git clone https://github.com/glideinWMS/glideinwms.git

if [ $(echo "$MYPYTHON" | cut -d '.' -f 1) == "python3" ]
then
    pushd glideinwms
    git checkout master
    popd
fi


# Link GlideinWMS repository
cd /usr/lib/$MYPYTHON/site-packages/
mv glideinwms/ fromrpm_glideinwms
ln -s /opt/gwms-git/glideinwms glideinwms

cd /var/lib/gwms-factory/
mkdir fromrpm
mv creation web-base fromrpm/
ln -s /usr/lib/$MYPYTHON/site-packages/glideinwms/creation creation
ln -s /usr/lib/$MYPYTHON/site-packages/glideinwms/creation/web_base web-base

cd /usr/sbin
mkdir -p /opt/fromrpm/usr_sbin

for i in \
checkFactory.py glideFactoryEntryGroup.py glideFactoryEntry.py \
glideFactory.py manageFactoryDowntimes.py stopFactory.py
do
    mv ${i}* /opt/fromrpm/usr_sbin/
    ln -s /usr/lib/$MYPYTHON/site-packages/glideinwms/factory/$i $i
    ln -s /usr/lib/$MYPYTHON/site-packages/glideinwms/factory/${i}o ${i}o
    ln -s /usr/lib/$MYPYTHON/site-packages/glideinwms/factory/${i}c ${i}c
done

for i in \
clone_glidein info_glidein reconfig_glidein
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


# Start factory
/usr/sbin/gwms-factory upgrade
/bin/systemctl start gwms-factory
