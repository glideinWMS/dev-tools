#!/bin/bash
# Check the validity of authentications
# - host certificate
# - frontend and factory proxies (*proxy in /etc/gwms-frontend and /etc/gwms-factory)
# - condor idtokens tokens (for users condor, frontend, gfactory, decisioengine)
# - custom provided files or directories
# First version 2023-02-17 - Marco Mambelli - marcom@fnal.gov

FRONTEND_USER=frontend
FACTORY_USER=gfactory
DE_USER=decisionengine
DEFAULT_USERS="condor,$FRONTEND_USER,$FACTORY_USER,$DE_USER"
AUTH_LIST_TOOLS=
CA_CERT_DIR=


# General functions

log_warn() {
    echo "$@" >&2
}

log_debug() {
    $VERBOSE && echo "$@" >&2 || true
}

out_verbose() {
     $VERBOSE && echo "$@" || true
}

# Convert time from date in the PEM certificate/proxy (ISO 8601) to timestamp (seconds from epoch)
# Compatible w/ Linux and BSD/Mac
# 1. time to convert in date format (e.g. [Thu] Mar 25 18:17:52 2021 GMT)
date2ts() {
    local res
    if ! res=$(date +%s -d "$1" 2>/dev/null); then
        # For BSD or Mac OS X
        if ! res=$(date  -j -f "%a %b %d %T %Y %Z" "$1" +"%s" 2>/dev/null); then  # try first w/ weekday
            if ! res=$(date  -j -f "%b %d %T %Y %Z" "$1" +"%s" 2>/dev/null); then  # w/o weekday
                log_warn "Unable to convert '$1' to seconds from epoch"
            fi
        fi
    fi
    echo "$res"
}

ts2date() {
  # Using function so it can be both on the line or piped
  # Unix timestamp to date conversion. Requires jq
  [[ -n "$1" ]] && { jq 'todate' <<< "$1" ; true;} || jq 'todate'
}

# Check that x509 CA certificates exist and set the env variable X509_CERT_DIR
# Using: X509_CERT_DIR, HOME, GLOBUS_LOCATION, X509_CADIR
# Return 1 and error string if failing
#        0 and certs dir path if succeeding
get_ca_certs_dir() {
    local cert_dir
    if [ -e "$X509_CERT_DIR" ]; then
        cert_dir="X509_CERT_DIR"
    elif [ -e "$HOME/.globus/certificates/" ]; then
        cert_dir="$HOME/.globus/certificates/"
    elif [ -e "/etc/grid-security/certificates/" ]; then
        cert_dir=/etc/grid-security/certificates/
    elif [ -e "$GLOBUS_LOCATION/share/certificates/" ]; then
        cert_dir="$GLOBUS_LOCATION/share/certificates/"
    elif [ -e "$X509_CADIR" ]; then
        cert_dir="$X509_CADIR"
    else
        STR="Could not find CA certificates!\n"
        STR+="Looked in:\n"
        STR+="	\$X509_CERT_DIR ($X509_CERT_DIR)\n"
        STR+="	\$HOME/.globus/certificates/ ($HOME/.globus/certificates/)\n"
        STR+="	/etc/grid-security/certificates/"
        STR+="	\$GLOBUS_LOCATION/share/certificates/ ($GLOBUS_LOCATION/share/certificates/)\n"
        STR+="	\$X509_CADIR ($X509_CADIR)\n"
        STR1=$(echo -e "$STR")
        log_debug "$STR1"
        return 1
    fi
    echo "$cert_dir"
}

# Check if all required commands are present
# Return 1 and error string if failing
#        0 and certs dir path if succeeding
check_auth_tools() {
    local cmd commands_found commands_missing commands_tmp
    # verify x509 commands, at least one needed
    for cmd in grid-proxy-info voms-proxy-info openssl ; do
        if ! command -v $cmd >& /dev/null; then
            log_debug "$cmd command not found in path!"
            commands_missing="$commands_missing,$cmd"
        else
	    commands_tmp="$commands_tmp,$cmd"
        fi
    done
    if [[ -z "$commands_tmp" ]]; then
        log_warn "No command to parse x509 proxies/certificates was found in the PATH. Exiting."
	return 1
    fi
    commands_found="$commands_tmp"
    commands_tmp=
    # verify tokens commands, all needed
    # shellcheck disable=SC2043  # at the moment a single command, OK
    for cmd in jq ; do
        if ! command -v $cmd >& /dev/null; then
            log_debug "$cmd command not found in path!"
	    commands_tmp="$commands_tmp,$cmd"
        else
	    commands_found="$commands_found,$cmd"
        fi
    done
    commands_missing="${commands_missing}${commands_tmp}"
    if [[ -n "$commands_tmp" ]]; then
        log_warn "A required command was not found in the PATH (${commands_tmp#,}). Exiting."
	return 1
    fi
    log_debug "Looking for x509 and token commands"
    log_debug "Found: ${commands_found#,}"
    log_debug "Missing (but not essential): ${commands_missing#,}"
    echo "${commands_found#,}"
    # return 0
}

# Get all x509 info using openssl
# 1. cert pathname
# Out: all cert info
# Ret: 0 - ok
#      1 - error reading the file
get_all_x509_openssl() {
    local output cert_pathname="$1"
    if [[ ! -r "$cert_pathname" ]]; then
        log_debug "Unable to read the file $cert_pathname"
        return 1
    fi
    output=$(openssl x509 -noout -subject  -issuer -dates -fingerprint -email -in "$cert_pathname" 2>/dev/null) || { log_debug "openssl command failed"; return 1; }
    echo "${output}"
}
# Get all x509 info
# 1. cert pathname
# Out: all cert info
# Ret: 0 - ok
#      1 - error reading the file
# Uses: AUTH_LIST_TOOLS
get_all_x509() {
    if [[ ",$AUTH_LIST_TOOLS," = *,voms-proxy-info,* ]]; then
        voms-proxy-info -all -file "$1"
    elif [[ ",$AUTH_LIST_TOOLS," = *,grid-proxy-info,* ]]; then
        grid-proxy-info -file "$1"
    else
        get_all_x509_openssl "$1"
    fi
}

# Get x509 subject using openssl (-subject)
# 1. cert pathname
# Out: subject
# Ret: 0 - ok
#      1 - error reading the file
get_subject_x509_openssl() {
    local output cert_pathname="$1"
    if [[ ! -r "$cert_pathname" ]]; then
        log_debug "Unable to read the file $cert_pathname"
        return 1
    fi
    output=$(openssl x509 -noout -subject -in "$cert_pathname" 2>/dev/null) || { log_debug "openssl command failed"; return 1; }
    # should remove the proxy parts from the subject? Needed if adding the subject in gridmap files
    # output=${output%%/CN=proxy*}
    echo "${output#subject= }"
}
get_subject_x509() {
    # -subject, -issuer, or -identity?
    # id=$(grid-proxy-info -identity 2>/dev/null)
    # id=$(voms-proxy-info -identity 2>/dev/null)
    get_subject_x509_openssl "$@"
}

# Get full token info
# 1. token pathname
# Out: all token info decoded
# Ret: 0 - ok
#      1 - error reading the file
get_all_token() {
    local output infile="$1"
    if [[ ! -r "$infile" ]]; then
        log_debug "Unable to read the file $infile"
        return 1
    fi
    output=$(jq -R 'gsub("-";"+") | gsub("_";"/") | split(".") | .[0],.[1] | @base64d | fromjson' "$infile") || { log_debug "jq command failed"; return 1; }
    echo "${output}"
}

# Get token subject (iss field)
# 1. token pathname
# Out: subject
# Ret: 0 - ok
#      1 - error reading the file
get_subject_token() {
    local output infile="$1"
    if [[ ! -r "$infile" ]]; then
        log_debug "Unable to read the file $infile"
        return 1
    fi
    output=$(jq -R 'gsub("-";"+") | gsub("_";"/") | split(".") | .[1] | @base64d | fromjson | .iss ' "$infile") || { log_debug "jq command failed"; return 1; }
    output=${output#\"}
    echo ${output%\"}
}

# Check validity and get x509 dates using openssl
# 1. cert pathname
# 2. time to compare in epoch format (optional)
# Out: start_ts:end_ts (seconds from epoch)
# Ret: 0 - the certificate is valid
#      1 - the certificate is expired or not yet valid (or the file is not readable)
check_dates_x509_openssl() {
    local cert_pathname="$1"
    local output start_date end_date start_epoch end_epoch epoch_now
    if [[ ! -r "$cert_pathname" ]]; then
        log_debug "Unable to read the file $cert_pathname"
        return 1
    fi
    output=$(openssl x509 -noout -dates -in "$cert_pathname" 2>/dev/null) || { log_debug "openssl command failed"; return 1; }
    start_date=$(echo $output | sed 's/.*notBefore=\(.*\).*not.*/\1/g')  # intentional word splittig to remove newline
    end_date=$(echo $output | sed 's/.*notAfter=\(.*\)$/\1/g')  # intentional word splittig to remove newline
    start_epoch=$(date2ts "$start_date")
    end_epoch=$(date2ts "$end_date")
    epoch_now=${2:-$(date +%s)}
    echo "${start_epoch}:$((end_epoch-epoch_now)):${end_epoch}"
    # Check validity
    if [[ "$start_epoch" -gt "$epoch_now" ]]; then
        log_debug "Certificate '$cert_pathname' is not yet valid"
        return 1
    else
	if [[ "$epoch_now" -gt "$end_epoch" ]]; then
	    log_debug "Certificate '$cert_pathname' is expired"
	    return 1
	fi
    fi
}
check_dates_x509() {
    check_dates_x509_openssl "$@"
}

# Check validity and get x509 dates using openssl
# 1. token pathname
# 2. time to compare in epoch format (optional)
# Out: start_ts:end_ts (seconds from epoch)
# Ret: 0 - the certificate is valid
#      1 - the certificate is expired or not yet valid (or the file is not readable)
check_dates_token() {
    local infile="$1"
    local output tstamps epoch_now
    if [[ ! -r "$infile" ]]; then
        log_debug "Unable to read the file $infile"
        return 1
    fi
    output=$(jq -R 'gsub("-";"+") | gsub("_";"/") | split(".") | .[1] | @base64d | fromjson | (.iat? | tostring) + ":" + (.exp | tostring) ' "$infile") || { log_debug "jq command failed"; return 1; }
    output=${output#\"}
    tstamps=${output%\"}
    epoch_now=${2:-$(date +%s)}
    echo "${tstamps%:*}:$((${tstamps#*:}-epoch_now)):${tstamps#*:}"
    # Check validity
    if [[ -n "${tstamps%:*}" ]] && [[ "${tstamps%:*}" -gt "$epoch_now" ]]; then
        log_debug "Token '$infile' is not yet valid"
        return 1
    else
	if [[ "$epoch_now" -gt "${tstamps#*:}" ]]; then
	    log_debug "Token '$infile' is expired"
	    return 1
	fi
    fi
}


# additional

extract_gridmap_DNs() {
    awk -F '"' '/CN/{dn=$2;if (dns=="") {dns=dn;} else {dns=dns "," dn}}END{print dns}' "$X509_GRIDMAP"
}

get_proxy_fname() {
    local cert_fname="$1"
    if [ -z "$cert_fname" ]; then
        if [ -n "$X509_USER_PROXY" ]; then
            cert_fname="$X509_USER_PROXY"
        # Ignoring the file in /tmp, it may be confusing
        #else
        #    cert_fname="/tmp/x509up_u`id -u`"
        fi
    fi
    # should it control if the file exists?
    log_debug "Using proxy file $cert_fname ($([ -e "$cert_fname" ] && echo "OK" || echo "No file"))"
    echo "$cert_fname"
}

get_status() {
    if $USE_COLOR; then
        $1 && echo -e "\033[0;32m[OK]\033[0m" || echo -e "\033[0;31m[invalid]\033[0m"
    else
        $1 && echo "[OK]" || echo "[invalid]"
    fi
    $1
}

# Check file permission and ownership
# 1. file path
# 2. expected owner, empty to skip (optional, default '')
# 3. octal permission, 'NO' to skip permissions check (optional, default: 600)
# Ret: 0 OK
#      1 wrong permission
#      2 wrong ownership
#      3 stat command failed
check_file_stats() {
    if ! "$CHECK_STATS"; then
        # skipping permissions check
        true
        return
    fi
    local out perm
    perm="600"
    [[ -n "$3" ]] && perm="$3" || true
    [[ "$perm" = NO && -n "$2" ]] && { true; return; } || true
    if ! out=$(stat -c "%U,%a" "$1" 2>/dev/null) ; then
        log_debug "Unable to check ownership and permissions of '$i'"
	return 3
    fi
    if ! [[ "$perm" = NO || "${out#*,}" = "$perm" ]]; then
        log_debug "Wrong permissions ($perm vs ${out#*,}) for '$1'"
	return 1
    fi
    if [[ -n "$2" ]] && [[ ! "${out%,*}" = "$2" ]]; then
        log_debug "Wrong ownership ($2 vs ${out%,*}) for '$1'"
	return 2
    fi
    true
}

# Check validity and get info about the auth file
# 1. file pathname
# 2. file owner to compare (optional)
# 3. file permission to compare (optional, default is 600, 'NO' to skip the check)
# 4. time to compare in epoch format (optional)
# Out: auth file info (more if verbose)
# Ret: 0 - the certificate is valid
#      1 - the certificate is expired or not yet valid (or the file is not readable) or has wrong permissions
check_x509() {
    local infile="$1" valid=true
    local output out out_status ftype
    if [[ ! -r "$infile" ]]; then
        log_debug "Unable to read the file $infile"
        return 1
    fi
    # x509 (PEM certificate)
    subj=$(get_subject_x509 "$infile")
    if ! tstamps=$(check_dates_x509 "$infile" "$4") ; then
        valid=false
    fi
    if ! check_file_stats "$infile" "$2" "$3"; then
        valid=false
    fi
    out_status=$(get_status $valid)
    if $VERBOSE_INFO; then
	echo "$infile $out_status"
        get_all_x509 "$infile"
	echo
    else
	echo "$infile $tstamps $subj $out_status"
    fi
    # return the valid status
    $valid
}

# Check validity and get info about the auth file
# 1. file pathname
# 2. file owner to compare (optional)
# 3. file permission to compare (optional, default is 600, 'NO' to skip the check)
# 4. time to compare in epoch format (optional)
# Out: auth file info (more if verbose)
# Ret: 0 - the token is valid
#      1 - the token is expired or not yet valid (or the file is not readable) or has wrong permissions
check_token() {
    local infile="$1" valid=true
    local output out out_status ftype
    if [[ ! -r "$infile" ]]; then
        log_debug "Unable to read the file $infile"
        return 1
    fi
    # jwt/tokes (ASCII text)
    subj=$(get_subject_token "$infile")
    if ! tstamps=$(check_dates_token "$infile" "$4") ; then
        valid=false
    fi
    if ! check_file_stats "$infile" "$2" "$3"; then
        valid=false
    fi
    out_status=$(get_status $valid)
    if $VERBOSE_INFO; then
	echo "$infile $out_status"
        get_all_token "$infile"
	echo
    else
	echo "$infile $tstamps $subj $out_status"
    fi
    # return the valid status
    $valid
}

# Check validity and get info about the auth file
# 1. file pathname
# 2... forwarded arguments, see check_token and check_x509
# Out: auth file info (more if verbose)
# Ret: 0 - the certificate/token is valid
#      1 - the certificate/token is expired or not yet valid (or the file is not readable) or has wrong permissions
check_file() {
    local infile valid=true
    local output out out_status ftype
    infile="$1"
    shift
    if [[ ! -r "$infile" ]]; then
        log_debug "Unable to read the file $infile"
        return 1
    fi
    ftype=$(file "$infile")
    if [[ "$ftype" = *certificate* ]]; then
        # x509 (PEM certificate)
	check_x509 "$infile" "$@"
    else
	# jwt/tokes (ASCII text)
	check_token "$infile" "$@"
    fi
}



help_msg() {
  cat << EOF
$0 [options]
Print info about authenticaton tokens/proxy/certificates
Options:
  -h          print this message
  -v          verbose (extra messages, but not all file info, see -i)
  -i          print all the token/proxy/certificate info
  -u  USERS   comma separtated list of users to check tokens for (default: condor,$DE_USER,$FRONTEND_USER,$FACTORY_USER)
  -d  DIR     directory to inspect (multival)
  -f  FILE    file to inspect (multival)
  -s          skip default checks (default: false, true if -d or -f are used)
  -P          do not check file ovnership and permissions
  -c          use colors in the output
The non-verbose output prints one line per file:
FNAME TIMES(not before:seconds left:not after)) SUBJECT(subject or iss) STATUS(ok or invalid)
Exit codes for errors:
  1 wrong command option
  2 invalid certificate or file
EOF
}


## Main

# Set defaults
declare -a FILE_LIST=()
declare -a DIR_LIST=()
VERBOSE=false
VERBOSE_INFO=false
DO_DEFAULT=true
CHECK_STATS=true
USE_COLOR=false

while getopts "hviu:f:d:sPc" option
do
  case "${option}"
  in
  h) help_msg; exit 0;;
  v) VERBOSE=true;;
  i) VERBOSE_INFO=true;;
  u) USERS=$OPTARG;;
  f) FILE_LIST+=("$OPTARG");;
  d) DIR_LIST+=("$OPTARG");;
  s) DO_DEFAULT=false;;
  P) CHECK_STATS=false;;
  c) USE_COLOR=true;;
  *) echo "Wrong option" >&2; help_msg >&2; exit 1;;
  esac
done
shift $((OPTIND -1))

if [[ ${#FILE_LIST[@]} -gt 0 || ${#DIR_LIST[@]} -gt 0 ]]; then
    DO_DEFAULT=false
fi
if $DO_DEFAULT; then
    [[ -z "$USERS" ]] && USERS="$DEFAULT_USERS" || true
fi

#id_subject=$(openssl x509 -noout -subject -in "$cert_fname" | cut -c10-) || [[ -z "$id_subject" ]]; then
#if ! id_subject=$(openssl x509 -noout -subject -in "$cert_fname" | cut -c10-) || [[ -z "$id_subject" ]]; then
                # if [ $? -ne 0 -o "x$id_subject" = "x" ]; then

print_instructions() {
  cat << EOF
*** Some instructions
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
}


if ! CA_CERT_DIR=$(get_ca_certs_dir); then
    log_warn "Unable to locate CA certificates, x509 will not work properly"
else
    out_verbose "CA cert dir: $CA_CERT_DIR"
fi

# Checking tools
out=$(check_auth_tools)
out_verbose "Tools found: $out"

ftc=

if $DO_DEFAULT; then
    if ! [[ "$(whoami)" = root ]]; then
        log_warn "It's recommended to run as root. Running as regular user you may not have access to some certificate or token."
    fi

    if [[ -r /etc/grid-security/hostcert.pem ]]; then
        out_verbose "*** Found host certificate, checking"
        #openssl x509 -noout -subject -dates -in /etc/grid-security/hostcert.pem
        #output=$(openssl x509 -noout -subject -dates -in /etc/grid-security/hostcert.pem 2>/dev/null)
        #echo "/etc/grid-security/hostcert.pem valid for sec: $seconds_to_expire"
        #if [ $seconds_to_expire -le 0 ]; then
        #  echo "!!! renew host certificate"
        #  ftc="$ftc /etc/grid-security/hostcert.pem"
        #fi
        # host cert, has 644 permission, using NO
        if ! check_x509 /etc/grid-security/hostcert.pem '' NO ; then
            ftc="$ftc,/etc/grid-security/hostcert.pem;"
        fi
    else
        out_verbose "*** Host certificate ('/etc/grid-security/hostcert.pem') not found"
    fi

    # Checking condor (also HTCondor-CE?)
    if [[ -d /etc/condor ]]; then
        out_verbose "*** Found HTCSS/HTCondor, checking '/etc/condor/tokens.d/'"
        for i in /etc/condor/tokens.d/*; do
            [[ ! -e "$i" ]] && continue
            if ! check_token "$i"; then
                ftc="$ftc,$i"
            fi
        done
    fi

    if [[ -d /etc/gwms-frontend ]]; then
        out_verbose "*** Found Frontend, checking '/etc/gwms-frontend/*proxy*'"
        for i in /etc/gwms-frontend/*proxy*; do
            [[ ! -e "$i" ]] && continue
            #su $FRONTEND_USER -c "voms-proxy-info -all -file $i"
            if ! check_x509 "$i" "$FRONTEND_USER"; then
                ftc="$ftc,$i"
            fi
        done
    fi

    if [[ -d /etc/gwms-factory ]]; then
        out_verbose "*** Found Factory, checking '/etc/gwms-factory/*proxy*'"
        #echo "Checking factory as $FACTORY_USER"
        for i in /etc/gwms-factory/*proxy*; do
            [ ! -e "$i" ] && continue
            #su $FACTORY_USER -c "voms-proxy-info -all -file $i"
            if ! check_x509 "$i" "$FACTORY_USER"; then
                ftc="$ftc,$i"
            fi
        done
    fi
fi

# Check user tokens
for i in ${USERS//,/ }
do
    out_verbose "*** Checking HTCSS tokens for $i"
    # get home dir (works also on Mac), otherwise `getent passwd "$USER" | cut -d: -f6`
    if homedir=$(bash -c "cd ~$(printf %q "$i") 2>/dev/null && pwd"); then
	if [[ ! -d "$homedir"/.condor/tokens.d/ ]]; then
	    log_debug "Directory not found in home directory: '$homedir/.condor/tokens.d/'"
	    continue
	fi
        for j in "$homedir"/.condor/tokens.d/*
        do
            if ! check_token "$j" "$i"; then
                ftc="$ftc,$j"
            fi
        done
    else
	    log_debug "Home directory not found: '~$i'"
    fi
done

# Check file list
for i in "${FILE_LIST[@]}"; do
    if ! check_file "$i"; then
        ftc="$ftc,$i"
    fi
done

# Check dir list
for i in "${DIR_LIST[@]}"; do
    if [[ -d "$i" ]]; then
        for j in "${i%/}"/*
        do
            if ! check_file "$j"; then
                ftc="$ftc,$j"
            fi
        done
    else
	log_warn "Directory not found: '$i'"
    fi
done

# Summary
if [[ -n "$ftc" ]]; then
  echo "*** Summary of invalid files: ${ftc#,}"
fi
