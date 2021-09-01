#!/bin/bash
# Find and package CA certificates
# Initial version 9/22/2014 - Marco Mambelli - marcom@fnal.gov

function find_ca_certs {
    if [ -e "$X509_CERT_DIR" ]; then
	  retv="$X509_CERT_DIR"
    elif [ -e "$HOME/.globus/certificates/" ]; then
	  retv="$HOME/.globus/certificates/"
    elif [ -e "/etc/grid-security/certificates/" ]; then
	  retv="/etc/grid-security/certificates/"
    else
        STR="Could not find grid-certificates!\n"
        STR+="Looked in:\n"
        STR+="	\$X509_CERT_DIR ($X509_CERT_DIR)\n"
        STR+="	\$HOME/.globus/certificates/ ($HOME/.globus/certificates/)\n"
        STR+="	/etc/grid-security/certificates/"
	STR1=`echo -e "$STR"`
        echo "$STR1" >2
        exit 1
    fi
    echo "$retv"
    return 0
}


PKG_FNAME="gwms-certpkg.tgz"

function help_msg {
  cat << EOF
$0 [ options ]
 -h        print this help message
 -c CA_DIR Path of the CA certificates directory [search availables]
 -o FNAME  Name of the CA certificate package [$PKG_FNAME]
 -r        Do not strip CSLs
 -v        verbose output
EOF
}

while getopts hc:o:rv option
do
  case "${option}"
  in
  "h") help_msg; exit 0;;
  "c") CA_DIR="${OPTARG}";;
  "o") PKG_FNAME="${OPTARG}";;
  "r") KEEP_CRL=yes;;
  "v") VERBOSE=yes;;
  esac
done

if [ -z "$CA_DIR" ]; then
  CA_DIR="`find_ca_certs`"
fi

[ -n "$VERBOSE" ] && echo "CA Certificates dir: $CA_DIR"

tmpdir="`mktemp -d`"

function get_abs_path {
  retv="`readlink -f $1 2> /dev/null`"
  # OSX has a different readlink
  if [ -n "$retv" ]; then
    echo "$retv"
  else
    if [[ ! "$1" == /.* ]]; then
      echo "`pwd`/$1"
    else
      echo "$1"
    fi
  fi
}

PKG_FNAME="`get_abs_path "$PKG_FNAME"`"
CA_DIR="`get_abs_path "$CA_DIR"`"

mkdir -p "$tmpdir/gwms_certificates"
pushd "$tmpdir" > /dev/null
cp "$CA_DIR"/* gwms_certificates/
if [ -z "$KEEP_CRL" ]; then
  rm -f gwms_certificates/*r0 2> /dev/null
fi
tar czf $PKG_FNAME gwms_certificates
popd > /dev/null
rm -rf "$tmpdir"

[ -n "$VERBOSE" ] && echo "CA Certificates packaged in: $PKG_FNAME"

