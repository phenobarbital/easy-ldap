#!/bin/bash
##
#  /usr/lib/easyldap/easyldap.sh
#
#  Common shell functions which may be used by easyldap script
#
##

VERSION='2.0'
scriptname='Easy LDAP'

## basic functions 

export NORMAL='\033[0m'
export RED='\033[1;31m'
export GREEN='\033[1;32m'
export YELLOW='\033[1;33m'
export WHITE='\033[1;37m'
export BLUE='\033[1;34m'


logMessage () {
  # scriptname=$(basename $0)
  if [ -f "$LOGFILE" ]; then
	echo "`date +"%D %T"` $scriptname : $@" >> $LOGFILE
  fi
}

get_version() 
{
	echo "Easy-LDAP $VERSION";
}

## message functions

#  If we're running verbosely show a message, otherwise swallow it.
#
message()
{
    message="$*"
    echo -e $message >&2;
    logMessage $message
}

info()
{
	message="$*"
    if [ "$VERBOSE" == "true" ]; then
		printf "$GREEN"
		printf "%s\n"  "$message" >&2;
		tput sgr0 # Reset to normal.
		echo -e `printf "$NORMAL"`
    fi
    logMessage $message
}

warning()
{
	message="$*"
    if [ "$VERBOSE" == "true" ]; then
		printf "$YELLOW"
		printf "%s\n"  "$message" >&2;
		tput sgr0 # Reset to normal.
		printf "$NORMAL"
    fi
    logMessage "WARN: $message"
}

debug()
{
	message="$*"
	if [ "$DEBUG" == "true" ]; then
    # if [ ! -z "$VERBOSE" ] || [ "$VERBOSE" == "true" ]; then
		printf "$BLUE"
		printf "%s\n"  "$message" >&2;
		tput sgr0 # Reset to normal.
		printf "$NORMAL"
    fi
    logMessage "DEBUG: $message"
}

error()
{
	message="$*"
	printf "$RED"
	printf "%s\n"  "$scriptname $message" >&2;
	tput sgr0 # Reset to normal.
	printf "$NORMAL"
	logMessage "ERROR:  $message"
	return 1
}

usage_err()
{
	error "$*"
	exit 1
}

optarg_check() 
{
    if [ -z "$2" ]; then
        usage_err "option '$1' requires an argument"
    fi
}

## info functions

datadir()
{
		if [ -d "/usr/share/easyldap/data" ]; then
			HOOKSDIR="/usr/share/easyldap/data"
		else
			HOOKSDIR="./data"
		fi
}

actiondir()
{
		if [ -d "/usr/share/easyldap/ldap.d" ]; then
			HOOKSDIR="/usr/share/easyldap/ldap.d"
		else
			HOOKSDIR="./ldap.d"
		fi
}

### domain info

define_domain()
{
	echo -n 'Please define a Domain name [ex: example.com]: '
	read _DOMAIN_
	if [ -z "$_DOMAIN_" ]; then
		message "error: Domain not defined"
		return 1
	else
		DOMAIN=$_DOMAIN_
	fi
}

get_hostname()
{
	if [ -z "$NAME" ]; then
		NAME=`hostname --short`
	fi
}

get_domain() 
{
	if [ -z "$DOMAIN" ] || [ "$DOMAIN" = "auto" ]; then
		# auto-configure domain:
		_DOMAIN_=`hostname -d`
		if [ -z "$_DOMAIN_" ]; then
			define_domain
		else
			DOMAIN=$_DOMAIN_
		fi
	fi
}

## Installation options

# install package with no prompt and default options
install_package()
{
	message "installing Debian package $@"
	#
	# Install the packages
	#
	DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get --option Dpkg::Options::="--force-overwrite" --option Dpkg::Options::="--force-confold" --yes --force-yes install "$@"
}

