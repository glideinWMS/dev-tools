#!/bin/bash
# script to list all fermicloud hosts from fermicloudui

OST_PROJECTS_LIST="osg glideinwms hepcloud scsservices"

help_msg() {
  cat << EOF
$0 [options]
Print info about the Fermicloud VMs
Options:
  -h          print this message
  -v          verbose
  -t          Create OS_TOKEN only if needed (will ask for services password)
  -r          Create OS_TOKEN all the times (will ask for services password)
  -p 	      project (Default: glideinwms)
              Projects: $OST_PROJECTS_LIST
Exit codes for errors:
1 wrong command option
2 invalid or missing OS token
3 openstack server command failed
EOF
}

get_token() {
  # Get OS token and save it in the cache
  # Globals: VERBOSE, OST_PROJECT
  # Env: HOME USER
  # The following command will ask for the service password
  $VERBOSE && echo "No OS token. Requesting it ($USER, $OST_PROJECT). You vill be asked for the service passord."
  OS_TOKEN=$(openstack --os-username=$USER  --os-user-domain-name=services --os-project-domain-name=services --os-project-name $OST_PROJECT  --os-auth-url http://131.225.153.227:5000/v3  --os-system-scope all token issue --format json | jq -r '.id')
  [ -z "$OS_TOKEN" ] && { echo "Unable to obtain OS token. Aborting." >&2; exit 2; }
  rm -f "$HOME"/.fclcache/token
  echo "OST_PROJECT=$OST_PROJECT" > "$HOME"/.fclcache/token
  chmod 600 "$HOME"/.fclcache/token
  echo "OS_TOKEN_DATE=$(date +%Y-%m-%dT%H:%M:%S%z)" >> "$HOME"/.fclcache/token
  echo "OS_TOKEN=$OS_TOKEN" >> "$HOME"/.fclcache/token
}

REFRESH=false
VERBOSE=false
GET_TOKEN=false
OST_PROJECT=glideinwms
while getopts "hvrtp:" option
do
  case "${option}"
  in
  h) help_msg; exit 0;;
  v) VERBOSE=true;;
  t) GET_TOKEN=true;;
  r) REFRESH=true;;
  p) OST_PROJECT=$OPTARG;;
  *) echo "Wrong option" >&2; help_msg >&2; exit 1;;
  esac
done

# Make sure that the OS token is available
if $REFRESH; then
  # Force update of the token
  get_token
else
  if [ -z "$OS_TOKEN" ]; then
    if [ -r "$HOME"/.fclcache/token ] && grep "OST_PROJECT=$OST_PROJECT"  "$HOME"/.fclcache/token > /dev/null; then
      .  "$HOME"/.fclcache/token
    elif $GET_TOKEN; then
      get_token
    fi
  fi
fi
[ -z "$OS_TOKEN" ] && { echo "Cannot proceed without OS token. Get one in advance or use '-t' or '-r'. Aborting." >&2;  $VERBOSE && help_msg >&2; exit 2; }

export OS_TOKEN

# Run the commands to get the list of VMs (OS servers)
#alias osnova='openstack --os-endpoint http://131.225.153.227:8774/v2.1     --os-token $OS_TOKEN server'
#osnova list --format json > ptp.json
#csv_table=$(cat ptp.json | jq -r '.[]|(.ID+","+.Networks+","+.Name)')

my_hosts_table=$(openstack --os-endpoint http://131.225.153.227:8774/v2.1 --os-token $OS_TOKEN server list --format json | jq -r '.[]|(.ID+","+.Networks+","+.Name)')
if [ $? -ne 0 ] || [ -z "$my_hosts_table" ]; then
  echo "Error in the openstack command. Aborting." >&2
  exit 3
fi
for i in $my_hosts_table; do
  mid=${i%%,*}
  mname=${i##*,}
  mip=${i#*,provider1=}
  mip=${mip%%,*}
  mhost=$(host $mip)
  mhost=${mhost##* }
  echo -e "$mid $mip\t ${mhost%.}\t $mname"
done
