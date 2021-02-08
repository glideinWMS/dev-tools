#!/bin/bash
# Check the validity of host certificate and frontend and factory proxies (*proxy in /etc/gwms-frontend and /etc/gwms-factory)
# First version 2014-09-22 - Marco Mambelli - marcom@fnal.gov

FRONTEND_USER=frontend
FACTORY_USER=factory

VERBOSE=yes

which voms-proxy-info > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "Missing voms-proxy-info. Please install it to continue."
  exit 1
fi

echo "*** Some instructions"
[ -n "$VERBOSE" ] && cat << 'EOF'
To renew host certificates on Fermicloud:
/etc/init.d/.credentials start

To renew the proxies:
pushd /etc/grid-security/
grid-proxy-init -cert hostcert.pem -key hostkey.pem -valid 999:0 -out /etc/gwms-frontend/fe_proxy
popd
/bin/cp -f /etc/gwms-frontend/fe_proxy /etc/gwms-frontend/vo_proxy
# as USER:  voms-proxy-init -voms osg -hours 900:0; mv /tmp/x509up_<USER_ID> ~/mm_proxy-last
ls -al ~USER/mm_proxy*
/bin/cp -f ~USER/mm_proxy* /etc/gwms-frontend/mm_proxy
/bin/cp -f /etc/gwms-frontend/vo_proxy /etc/gwms-frontend/fe_proxy
chown frontend: /etc/gwms-frontend/*
ls -al /etc/gwms-frontend/

If a KCA proxy is required:
yum install krb5-fermi-getcert
kinit
get-cert
OR look for make-kca-cert (other utility script)

EOF


echo "*** Checking host certificate"
#openssl x509 -noout -subject -dates -in /etc/grid-security/hostcert.pem
output=$(openssl x509 -noout -subject -dates -in /etc/grid-security/hostcert.pem 2>/dev/null)
[ -n "$VERBOSE" ] && echo "$output"

start_date=$(echo $output | sed 's/.*notBefore=\(.*\).*not.*/\1/g')
end_date=$(echo $output | sed 's/.*notAfter=\(.*\)$/\1/g')

# For OS X: date  -j -f "%b %d %T %Y %Z" "$start_date" +"%s"
start_epoch=$(date +%s -d "$start_date")
end_epoch=$(date +%s -d "$end_date")
epoch_now=$(date +%s)

if [ "$start_epoch" -gt "$epoch_now" ]; then
  echo "Host certificate is not yet valid"
  seconds_to_expire=0
else
  seconds_to_expire=$(($end_epoch - $epoch_now))
fi

echo "/etc/grid-security/hostcert.pem valid for sec: $seconds_to_expire"
if [ $seconds_to_expire -le 0 ]; then
  echo "!!! renew host certificate"
  ftc="$ftc /etc/grid-security/hostcert.pem"
fi
echo


#echo "Checking frontend as $FRONTEND_USER"
# factory or frontend user may not be there
echo "*** Checking frontend as root"

for i in /etc/gwms-frontend/*proxy*; do
  [ ! -e "$i" ] && continue
  echo "* Checking: $i"
  #su $FRONTEND_USER -c "voms-proxy-info -all -file $i"
  outs=$(voms-proxy-info -all -file "$i")
  [ -n "$VERBOSE" ] && echo "$outs"
  echo "$outs" | grep -q "timeleft  : 0"
  if [ $? -eq 0 ]; then
    echo " !!! zero length proxy found: $i"
    ftc="$ftc $i"
  fi
  if [ ! "$(stat -c "%U %a" "$i")" = "$FRONTEND_USER 600" ]; then
    echo " !!! wrong owner or permissions: $i"
    ftc="$ftc $i"
  fi
  echo
done

#echo "Checking factory as $FACTORY_USER"
echo "*** Checking factory as root"
for i in /etc/gwms-factory/*proxy*; do
  [ ! -e "$i" ] && continue
  echo "* Checking: $i"
  #su $FACTORY_USER -c "voms-proxy-info -all -file $i"
  outs=$(voms-proxy-info -all -file $i)
  [ -n "$VERBOSE" ] && echo "$outs"
  echo $outs | grep -q "timeleft  : 0"
  if [ $? -eq 0 ]; then
    echo " !!! zero length proxy found: $i"
    ftc="$ftc $i"
  fi
  if [ ! "$(stat -c "%U %a" "$i")" = "$FACTORY_USER 600" ]; then
    echo " !!! wrong owner or permissions: $i"
    ftc="$ftc $i"
  fi
  echo
done

if [ -n "$ftc" ]; then
  echo "*** Files to check: $ftc"
fi
