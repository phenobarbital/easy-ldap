#!/bin/bash

# Authors:
# Jesus Lara <jesuslara@devel.com.ve>
# version: 2.0
# Copyright (C) 2010 Jesus Lara

# ldap_functions
# incorpora todas las funciones de configuracion y pruebas de servidor openldap

## ldap commands #######

SLAPADD="$(which slapadd)"
SLAPPASSWD="$(which slappasswd)"
SLAPINDEX="$(which slapindex) -F $LDAP_DIRECTORY -n 2"
SLAPTEST="$(which slaptest) -d2 -u"
SLAPACL="$(which slapacl) -F $LDAP_DIRECTORY -v"

LDAPADD="$(which ldapadd) -H ldapi:/// -Y EXTERNAL -Q"
LDAPADDUSER="$(which ldapadd) -H ldapi:/// -x "
LDAPSEARCH="$(which ldapsearch) -H ldapi:///"
CN_ADMIN="cn=admin,$BASE_DN"

#############################################################

ldap_configure()
{
	# configurando /etc/default/slapd
	sed -i "s/SLAPD_SERVICES=\"ldap:\/\/\/ ldapi:\/\/\/\"/SLAPD_SERVICES=\"ldap:\/\/\/ ldapi:\/\/\/ ldaps:\/\/\/\"/g" /etc/default/$LDAP_SERVER

	# clave tanto de usuario cn=admin,cn=config como del usuario admin del LDAP
	get_admin_password

	echo "Clave cifrada: "
	echo `$SLAPPASSWD -uvs $PASS`
	echo

	info "Configure cn=config"
	cn_config
	
	info "Enable basic modules"
	ldap_modules
	
	# create directory tree
	info "Creating Directory Tree $BASE_DN"
	
	# backend optimize
	info "Optimizing $BACKEND backend"
	case "$BACKEND" in
		"mdb") mdb_tunning 1;;
		"hdb") hdb_tunning 1;;
		*)  break;;
	esac
	
	# ejecutar los hooks del directorio ldap.d
	return 0	
}

cn_config()
{
# configuracion basica de cn=config
$LDAPADD << EOF
dn: cn=config
changetype: modify
replace: olcAttributeOptions
olcAttributeOptions: lang-
-
replace: olcToolThreads
olcToolThreads: 8
-
replace: olcThreads
olcThreads: 32
-
replace: olcSockbufMaxIncoming
olcSockbufMaxIncoming: 262143
-
replace: olcSockbufMaxIncomingAuth
olcSockbufMaxIncomingAuth: 16777215
-
replace: olcReadOnly
olcReadOnly: FALSE
-
replace: olcReverseLookup
olcReverseLookup: FALSE
-
replace: olcServerID
olcServerID: 1 ldap://$SERVERNAME
EOF

# configuracion de olcDatabase(0)
$LDAPADD << EOF
dn: olcDatabase={0}config,cn=config
changetype: modify
replace: olcRootPW
olcRootPW: `$SLAPPASSWD -uvs $PASS`
-
replace: olcAccess
olcAccess: {0}to * by dn.exact=gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth manage by dn.exact="$CN_ADMIN" manage by * break
olcAccess: {1}to dn="" by * read
olcAccess: {2}to dn.subtree="" by * read
olcAccess: {3}to dn="cn=Subschema" by * read
EOF

}

# habilitando todos los modulos necesarios:
ldap_modules()
{
$LDAPADD << EOF
dn: cn=module{0},cn=config
changetype: modify
add: olcModuleLoad
olcModuleload: back_mdb
olcModuleload: unique
olcModuleload: back_ldap
olcModuleload: syncprov
olcModuleload: dynlist
olcModuleload: refint
olcModuleload: constraint
olcModuleload: back_monitor
olcModuleload: ppolicy
olcModuleload: accesslog
olcModuleload: auditlog
olcModuleload: valsort
olcModuleload: memberof
EOF
}

test_config()
{
	$SLAPTEST -F $LDAP_DIRECTORY
	if [ "$?" -ne "0" ]; then
		debug "OpenLDAP incorrect configuration, please check for errors"
		return 1
	else
		return 0
	fi
}

hdb_tunning()
{
	IDX=$@
# tunning de la DB
$LDAPADD << EOF
dn: olcDatabase={$IDX}hdb,cn=config
changetype: modify
replace: olcRootPW
olcRootPW: `$SLAPPASSWD -uvs $PASS`
-
replace: olcLastMod
olcLastMod: TRUE
-
replace: olcAddContentAcl
olcAddContentAcl: TRUE
-
replace: olcReadOnly
olcReadOnly: FALSE
-
replace: olcSizeLimit
olcSizeLimit: $SIZELIMIT
-
replace: olcTimeLimit
olcTimeLimit: $TIMELIMIT
-
replace: olcDbIDLcacheSize
olcDbIDLcacheSize: 500000
-
replace: olcDbCacheFree
olcDbCacheFree: 1000
-
replace: olcDbDNcacheSize
olcDbDNcacheSize: 0
-
replace: olcDbCacheSize
olcDbCacheSize: 5000
-
replace: olcDbCheckpoint
olcDbCheckpoint: 1024 30
-
replace: olcMaxDerefDepth
olcMaxDerefDepth: 15
-
replace: olcSyncUseSubentry
olcSyncUseSubentry: FALSE
-
replace: olcMonitoring
olcMonitoring: TRUE
-
replace: olcDbConfig
olcDbConfig: {0}set_cachesize 0 10485760 0
olcDbConfig: {1}set_lk_max_objects 1500
olcDbConfig: {2}set_lk_max_locks 1500
olcDbConfig: {3}set_lk_max_lockers 1500
olcDbConfig: {4}set_lg_bsize 2097152
olcDbConfig: {5}set_flags DB_LOG_AUTOREMOVE
EOF
}

mdb_tunning()
{
	IDX=$@
# tunning de la DB
$LDAPADD << EOF
dn: olcDatabase={$IDX}hdb,cn=config
changetype: modify
replace: olcRootPW
olcRootPW: `$SLAPPASSWD -uvs $PASS`
-
replace: olcLastMod
olcLastMod: TRUE
-
replace: olcAddContentAcl
olcAddContentAcl: TRUE
-
replace: olcReadOnly
olcReadOnly: FALSE
-
replace: olcSizeLimit
olcSizeLimit: 2000
-
replace: olcTimeLimit
olcTimeLimit: 60
-
replace: olcDbIDLcacheSize
olcDbIDLcacheSize: 500000
-
replace: olcDbCacheFree
olcDbCacheFree: 1000
-
replace: olcDbDNcacheSize
olcDbDNcacheSize: 0
-
replace: olcDbCacheSize
olcDbCacheSize: 5000
-
replace: olcDbCheckpoint
olcDbCheckpoint: 1024 30
-
replace: olcMaxDerefDepth
olcMaxDerefDepth: 15
-
replace: olcSyncUseSubentry
olcSyncUseSubentry: FALSE
-
replace: olcMonitoring
olcMonitoring: TRUE
-
replace: olcDbConfig
olcDbConfig: {0}set_cachesize 0 10485760 0
olcDbConfig: {1}set_lk_max_objects 1500
olcDbConfig: {2}set_lk_max_locks 1500
olcDbConfig: {3}set_lk_max_lockers 1500
olcDbConfig: {4}set_lg_bsize 2097152
olcDbConfig: {5}set_flags DB_LOG_AUTOREMOVE
EOF

# MDB options
$LDAPADD << EOF
dn: olcDatabase={$IDX}hdb,cn=config
changetype: modify
replace: olcDbMaxReaders
olcDbMaxReaders: 0
-
replace: olcDbMode
olcDbMode: 0600
-
replace: olcDbSearchStack
olcDbSearchStack: 16
-
replace: olcDbNoSync
olcDbNoSync: FALSE
-
replace: olcDbEnvFlags
olcDbEnvFlags: {0}writemap
olcDbEnvFlags: {1}nometasync
EOF
}

