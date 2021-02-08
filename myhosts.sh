#!/bin/bash
# script to list all fermicloud hosts from fermicloudui

help_msg() {
  cat << EOF
$0 [options]
Print info about the fermicloud VMs
Options:
  -h          print this message
  -v          verbose
  -r          refresh credentials
EOF
}

REFRESH=false
VERBOSE=false
while getopts "hvr" option
do
  case "${option}"
  in
  h) help_msg; exit 0;;
  r) REFRESH=true;;
  v) VERBOSE=true;;
  *) echo "Wrong option"; help_msg; exit 1;;
  esac
done

if $REFRESH; then
#source OpenNebula/.one-env
#source /cloud/images/OpenNebula/scripts/one3.2/user.sh > /dev/null
#if [ $? -ne 0 ]; then
#  echo "Error in setting environment"
#  exit 1
#fi
  . /etc/profile.d/one4x.sh
  . /etc/profile.d/one4x_user_credentials.sh > /dev/null
fi

if $VERBOSE; then
  #onevm list |grep marco | awk '{ print $1 }' | xargs onevm show | grep IP_P | cut -d= -f2 | cut -d, -f1 | xargs -n1 host
  onevm list | grep $USER | awk '{ print $1 }' | xargs -n1 onevm show | grep ETH0_IP | cut -d\" -f2 | xargs -n1 host

  echo
fi

my_host_ids=`onevm list | grep $USER | awk '{ print $1 ":" $4 }'`
for i in $my_host_ids; do
  i_ip=`onevm show ${i%%:*} | grep ETH0_IP | cut -d\" -f2`
  i_host=`host $i_ip`
  i_host=${i_host##* }
  echo -e "${i%%:*} ${i_ip}\t ${i_host%.}\t ${i#*:}"
done
