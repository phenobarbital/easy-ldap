#!/bin/bash
##
#  /usr/lib/easyldap/easyldap.sh
#
#  Common shell functions which may be used by easyldap script
#
##

VERSION='2.0'
scriptname='Easy LDAP'

# debian options
INSTALLER="$(which aptitude) -y"
SERVICE="$(which service)"

# packages
PACKAGES=( ldap-utils lsof openssl libslp1 ssl-cert ca-certificates )
SASL_PKGS=( sasl2-bin libsasl2-modules-ldap libsasl2-2 )
		
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
	MESSAGE=$(cat << _MSG
Easy-LDAP $VERSION
Copyright (C) 2012 Jesus Lara (phenobarbital) <jesuslarag@gmail.com>"
Licencia GPLv3+: GPL de GNU versión 3 o posterior <http://gnu.org/licenses/gpl.html>"

Esto es software libre; usted es libre de cambiarlo y redistribuirlo.
NO hay GARANTÍA, a la extensión permitida por la ley.
_MSG
)

echo "$MESSAGE"
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

configdir()
{
	if [ -e "/etc/easyldap.conf" ]; then
		. /etc/easyldap.conf
	else
		. ./etc/easyldap.conf
	fi
}

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

check_domain()
{
	if [[ "${#1}" -gt 254 ]] || [[ "${#1}" -lt 2 ]]; then
		usage_err "domain name '$1' is an invalid domain name"
	fi
	dom=$(echo $1 | grep -P '(?=^.{5,254}$)(^(?:(?!\d+\.)[a-zA-Z0-9_\-]{1,63}\.?)+(?:[a-zA-Z]{2,})$)')
	if [ -z $dom ]; then
		usage_err "domain name '$1' is an invalid domain name"
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
	lsof /var/lib/dpkg/lock >/dev/null 2>&1
	if [ $? = 0 ]; then
		echo "dpkg lock in use"
		exit 1
	fi
	DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get --option Dpkg::Options::="--force-overwrite" --option Dpkg::Options::="--force-confold" --yes --force-yes install "$@"
}

# remove a package
remove_package()
{
	message "uninstall Debian package $@"
	lsof /var/lib/dpkg/lock >/dev/null 2>&1
	if [ $? = 0 ]; then
		echo "dpkg lock in use"
		exit 1
	fi
	DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get --purge remove "$@"
}

# test if a package exists in repository
test_package()
{
	lsof /var/lib/dpkg/lock >/dev/null 2>&1
	if [ $? = 0 ]; then
		echo "dpkg lock in use"
		exit 1
	fi
	debug "Testing if package $@ is available"
	DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get --simulate install "$@" >/dev/null 2>&1
	if [ $? -ne 0 ]; then
		return 1
	else
		return 0
	fi
}

# test if a package is already installed
is_installed()
{
	# test installation package
	debug "Test if $@ is installed"
	dpkg-query -s "$@" >/dev/null 2>&1
	if [ $? -ne 0 ]; then
		return 1
	else
		return 0
	fi
}

# set cn=admin password
function get_admin_password() {
	echo
	echo "= Admin Account = "
	echo
	echo "Admin Account for this installation is: "
	echo "cn=admin,$LDAP_SUFFIX"
	echo 
	echo "Admin for cn=config is:"
	echo "cn=admin,cn=config"
	echo
	echo "Please, set password for this account:"
	while /bin/true; do
        echo -n "New password: "
        stty -echo
        read pass1
        stty echo
        echo
        if [ -z "$pass1" ]; then
            echo "Error, password cannot be empty"
            echo
            continue
        fi
        echo -n "Repeat new password: "
        stty -echo
        read pass2
        stty echo
        echo
        if [ "$pass1" != "$pass2" ]; then
            echo "Error, passwords don't match"
            echo
            continue
        fi
        PASS="$pass1"
        break
	done
    if [ -n "$PASS" ]; then
        return 0
    fi
    return 1
}

#### LDAP functions ####

# returns base suffix
function get_basedn() {
	if [ -z "$BASE_DN" ]; then
		old_ifs=${IFS}
		IFS="."
		for component in $DOMAIN; do
			result="$result,dc=$component"
		done
		IFS="${old_ifs}"
		BASE_DN="${result#,}"
	fi
	return 0
}
