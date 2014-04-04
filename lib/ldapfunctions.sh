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
	
	info "Configure SSL and SASL"
	ssl_configure
	sasl_configure
	
	info "Enable basic modules"
	ldap_modules
	
	info "Configure Logging"
	log_configure
	
	info "Configure monitor database cn=monitor"
	configure_monitor
	
	# configure overlays
	overlay_configure 1
	
	# loading schemas
	schema_configure
	
	# ACL control
	acl_configure 1
	
	# backend optimize
	info "Optimizing $BACKEND backend"
	case "$BACKEND" in
		"mdb") mdb_tunning 1;;
		"hdb") hdb_tunning 1;;
		*)  break;;
	esac
	
	# configure indexes
	tree_indexing 1	
	
	$SLAPTEST -F $LDAP_DIRECTORY
	if [ "$?" -ne "0" ]; then
		error "Failed to check openLDAP configuration"
		exit 1
	fi
	# first restart
	service $LDAP_SERVER restart
	
	# loading directory tree
	info "Creating Directory Tree $BASE_DN"
	load_basic_dit
	
	info "Configuring Default Password Policy"
	# password policies
	password_policies 1
	
	# execute all hooks in ldap.d directory
	actiondir
	for f in $(find $HOOKSDIR/* -maxdepth 1 -executable -type f ! -iname "*.md" ! -iname ".*" | sort --numeric-sort); do
		. $f
	done
	
	# re-indexing tree
	
	# testing ACL
	acl_testing
	
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

# configuracion de reglas de control de acceso
acl_configure() {
	IDX=$@
	debug "Configuring ACL rules for openLDAP"
# Configuring Access Control List"
$LDAPADD << EOF
dn: olcDatabase={$IDX}$BACKEND,cn=config
changetype: modify
replace: olcAccess
olcAccess: {0}to attrs=userPassword,sambaNTPassword,sambaLMPassword,sambaPwdLastSet,sambaPwdMustChange,sambaPasswordHistory,shadowLastChange,shadowMin,shadowMax,shadowWarning,shadowInactive,shadowExpire,shadowFlag,pwdChangedTime,pwdAccountLockedTime,pwdFailureTime,pwdHistory,pwdGraceUseTime,pwdReset by self write by anonymous auth by dn="cn=admin,$BASE_DN" write by group/groupOfNames/member.exact="cn=account-admins,cn=groups,cn=ldap,ou=services,$BASE_DN" write by group/groupOfNames/member.exact="cn=ldap-admins,cn=groups,cn=ldap,ou=services,$BASE_DN" write by set="[cn=administrators,cn=groups,cn=ldap,ou=services,$BASE_DN]/memberUid & user/uid" manage by group/groupOfNames/member.exact="cn=replicators,cn=groups,cn=ldap,ou=services,$BASE_DN" read by * none
olcAccess: {1}to dn.base="" by * read
olcAccess: {2}to attrs=carLicense,homePhone,mobile,pager,telephoneNumber by self write by set="this/manager & user" write by set="this/manager/secretary & user" write by dn="cn=account-admins,cn=groups,cn=ldap,ou=services,$BASE_DN" write
olcAccess: {3}to attrs=gidNumber,uidNumber,homeDirectory,uid,loginShell,gecos by group/groupOfNames/member.exact="cn=ldap-admins,cn=groups,cn=ldap,ou=services,$BASE_DN" manage by set="[cn=administrators,cn=groups,cn=ldap,ou=services,$BASE_DN]/memberUid & user/uid" manage by group.exact="cn=readers,cn=groups,cn=ldap,ou=services,$BASE_DN" read by dn="cn=account-admins,cn=groups,cn=ldap,ou=services,$BASE_DN" write by group.exact="cn=replicators,cn=groups,cn=ldap,ou=services,$BASE_DN" write
olcAccess: {5}to dn.subtree="cn=policies,ou=services,$BASE_DN" by group/groupOfNames/member.exact="cn=account-admins,cn=groups,cn=ldap,ou=services,$BASE_DN" write by group/groupOfNames/member.exact="cn=ldap-admins,cn=groups,cn=ldap,ou=services,$BASE_DN" manage by group/groupOfNames/member.exact="cn=replicators,cn=groups,cn=ldap,ou=services,$BASE_DN" read by group/groupOfNames/member.exact="cn=readers,cn=groups,cn=ldap,ou=services,$BASE_DN" by * read
olcAccess: {6}to dn.subtree="ou=people,$BASE_DN" by self write by group/groupOfNames/member.exact="cn=ldap-admins,cn=groups,cn=ldap,ou=services,$BASE_DN" manage by group/groupOfNames/member.exact="cn=account-admins,cn=groups,cn=ldap,ou=services,$BASE_DN" write by group/groupOfNames/member.exact="cn=replicators,cn=groups,cn=ldap,ou=services,$BASE_DN" read by anonymous auth by * read
olcAccess: {7}to dn.subtree="ou=services,$BASE_DN" by self write by group/groupOfNames/member.exact="cn=ldap-admins,cn=groups,cn=ldap,ou=services,$BASE_DN" manage by group/groupOfNames/member.exact="cn=replicators,cn=groups,cn=ldap,ou=services,$BASE_DN" read by anonymous auth by * read
olcAccess: {8}to * by self write by set="[cn=administrators,cn=groups,cn=ldap,ou=services,$BASE_DN]/memberUid & user/uid" write by dn="cn=administrator,cn=ldap,ou=services,$BASE_DN" write  by  by group/groupOfNames/member.exact="cn=account-admins,cn=groups,cn=ldap,ou=services,$BASE_DN" write by group/groupOfNames/member.exact="cn=ldap-admins,cn=groups,cn=ldap,ou=services,$BASE_DN" manage by group/groupOfNames/member.exact="cn=replicators,cn=groups,cn=ldap,ou=services,$BASE_DN" read by anonymous auth by * read
EOF
echo
echo " == Configuracion de Limites == "
echo
# configuracion de los limites:
$LDAPADD << EOF
dn: olcDatabase={$IDX}$BACKEND,cn=config
changetype: modify
add: olcLimits
olcLimits: {0}dn.base="cn=admin,$BASE_DN" size.soft=unlimited  size.hard=unlimited  time.soft=unlimited  time.hard=unlimited
olcLimits: {1}group/groupOfNames/member="cn=replicators,cn=groups,cn=ldap,ou=services,$BASE_DN" size=unlimited time=unlimited
olcLimits: {2}group/groupOfNames/member="cn=ldap-admins,cn=groups,cn=ldap,ou=services,$BASE_DN" size=unlimited time=unlimited
olcLimits: {3}group/groupOfNames/member="cn=account-admins,cn=groups,cn=ldap,ou=services,$BASE_DN" size=unlimited time=unlimited
EOF
}

acl_testing()
{
info " Testing ACLs "
debug "  * - Testing cn=administrator permissions to ou=people - * "
$SLAPACL -D "cn=administrator,cn=ldap,ou=services,$BASE_DN" -b "$BASE_DN" "ou/write:people"
}

log_configure() {

debug "Configure slapd logging"

# make new logging folder
if [ ! -d "/var/log/slapd" ]; then
	mkdir /var/log/slapd
fi
chmod 755 /var/log/slapd/
chown $LDAP_USER:$LDAP_GROUP /var/log/slapd/ -R

# change rsyslog
# Redirect all log files through rsyslog.
sed -i "/local4.*/d" /etc/rsyslog.conf

# si no se encuentra la linea, se agrega a rsyslog
if [ `cat /etc/rsyslog.conf | grep slapd.log | wc -l` == "0" ]; then
cat >> /etc/rsyslog.conf << EOF
local4.*                        /var/log/slapd/slapd.log
EOF
fi

# LDAP logging
$LDAPADD << EOF
dn: cn=config
changetype:modify
replace: olcLogFile
olcLogFile: /var/log/slapd/slapd.log
EOF

# Logging level
$LDAPADD << EOF
dn: cn=config
changetype:modify
replace: olcLogLevel
olcLogLevel: config stats shell acl
-
replace: olcIdleTimeout
olcIdleTimeout: 30
-
replace: olcGentleHUP
olcGentleHUP: FALSE
-
replace: olcConnMaxPending
olcConnMaxPending: 100
EOF

# configuring logrotate
cat <<EOF > /etc/logrotate.d/slapd
/var/log/slapd/slapd.log {
        daily
        missingok
        rotate 7
        compress
        copytruncate
        notifempty
        create 640 openldap openldap
}
EOF

# reiniciando rsyslog
$SERVICE rsyslog restart
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

# configure database monitor
configure_monitor()
{
debug "creating cn=monitor database"

$LDAPADD << EOF
dn: olcDatabase=monitor,cn=config
objectClass: olcDatabaseConfig
olcDatabase: monitor
olcAccess: {0}to * by dn.exact="cn=admin,$BASE_DN" write by * none
olcAccess: {1}to dn.subtree="cn=monitor" by dn.exact="cn=admin,$BASE_DN" write by group/groupOfNames/member.exact="cn=ldap-admins,cn=groups,cn=ldap,ou=services,$BASE_DN" read by group/groupOfNames/member.exact="cn=ldap-monitors,cn=groups,cn=ldap,ou=services,$BASE_DN" read by users read by * none
olcAccess: {2}to dn.children="cn=monitor" by dn.exact="cn=admin,$BASE_DN" write by group/groupOfNames/member.exact="cn=ldap-admins,cn=groups,cn=ldap,ou=services,$BASE_DN" read by group/groupOfNames/member.exact="cn=ldap-monitors,cn=groups,cn=ldap,ou=services,$BASE_DN" read
olcLastMod: TRUE
olcMaxDerefDepth: 15
olcReadOnly: FALSE
olcRootDN: cn=config
olcMonitoring: TRUE
EOF
# y agregamos reglas de control de acceso en frontend
$LDAPADD << EOF
dn: olcDatabase={-1}frontend,cn=config
changetype: modify
replace: olcAccess
olcAccess: {0}to * by dn.exact=gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth manage by * break
olcAccess: {1}to dn.exact="" by * read
olcAccess: {2}to dn.base="cn=Subschema" by * read
olcAccess: {3}to dn.subtree="cn=monitor" by dn="cn=admin,$BASE_DN" read
olcAccess: {4}to dn.subtree="" by group/groupOfNames/member.exact="cn=ldap-admins,cn=groups,cn=ldap,ou=services,$BASE_DN" read by group/groupOfNames/member.exact="cn=ldap-monitors,cn=groups,cn=ldap,ou=services,$BASE_DN" read
EOF
}

# configure overlays basicos
overlay_configure()
{
	IDX=$@
	info "Configuring Overlays (Modules)"

debug "enable referencial integrity"
$LDAPADD << EOF
dn: olcOverlay=refint,olcDatabase={$IDX}$BACKEND,cn=config
changetype: add
objectClass: olcRefintConfig
objectClass: olcOverlayConfig
objectClass: olcConfig
objectClass: top
olcOverlay: refint
olcRefintAttribute: member
olcRefintAttribute: uniqueMember
olcRefintNothing: cn=admin,$BASE_DN
EOF
debug "Enable Unique Overlay"
$LDAPADD << EOF
dn: olcOverlay=unique,olcDatabase={$IDX}$BACKEND,cn=config
objectClass: olcOverlayConfig
objectClass: olcUniqueConfig
olcOverlay: unique
olcUniqueURI: ldap:///ou=people,$BASE_DN?mail,employeeNumber?sub?(objectClass=inetOrgPerson)
olcUniqueURI: ldap:///ou=groups,$BASE_DN?gidNumber?one?(objectClass=posixGroup)
olcUniqueURI: ldap:///ou=people,$BASE_DN?uidNumber?one?(objectClass=posixAccount)
EOF
debug "Constraint overlay"
$LDAPADD << EOF
dn: olcOverlay=constraint,olcDatabase={$IDX}$BACKEND,cn=config 
changetype: add
objectClass: olcOverlayConfig
objectClass: olcConstraintConfig
olcOverlay: constraint
olcConstraintAttribute: jpegPhoto size 131072
olcConstraintAttribute: userPassword count 5
olcConstraintAttribute: uidNumber regex ^[[:digit:]]+$
olcConstraintAttribute: gidNumber regex ^[[:digit:]]+$
EOF
debug " = MemberOf = "
$LDAPADD << EOF
dn: olcOverlay=memberof,olcDatabase={$IDX}$BACKEND,cn=config
changetype: add
objectClass: olcMemberOf
objectClass: olcOverlayConfig
objectClass: olcConfig
objectClass: top
olcOverlay: memberof
olcMemberOfDangling: ignore
olcMemberOfRefInt: TRUE
olcMemberOfGroupOC: groupOfNames
olcMemberOfMemberAD: member
olcMemberOfMemberOfAD: memberOf
EOF
debug " SyncProv replication overlay "
# configuracion de overlay de sincronia para DB
$LDAPADD << EOF
dn: olcOverlay=syncprov,olcDatabase={$IDX}$BACKEND,cn=config
changetype: add
objectClass: olcOverlayConfig
objectClass: olcSyncProvConfig
olcOverlay: syncprov
olcSpCheckpoint: 20 10
olcSpSessionlog: 500
olcSpNoPresent: TRUE
EOF
# sincronia de la db-config
$LDAPADD << EOF
dn: olcOverlay=syncprov,olcDatabase={0}config,cn=config
changetype: add
objectClass: olcOverlayConfig
objectClass: olcSyncProvConfig
olcOverlay: syncprov
olcSpCheckpoint: 20 10
olcSpSessionlog: 500
olcSpNoPresent: TRUE
EOF
}

password_policies()
{
	IDX=$@
	debug "Password Policies"
$LDAPADD << EOF
dn: olcOverlay=ppolicy,olcDatabase={$IDX}$BACKEND,cn=config
changetype: add
objectClass: olcOverlayConfig
objectClass: olcPPolicyConfig
olcOverlay: ppolicy
olcPPolicyDefault: cn=default,cn=policies,ou=services,$BASE_DN
olcPPolicyHashCleartext: TRUE
olcPPolicyUseLockout: FALSE
EOF
# cargamos las reglas del password policy
$LDAPADDUSER -D "cn=admin,$BASE_DN" -w $PASS << EOF
dn: cn=default,cn=policies,ou=services,$BASE_DN
cn: default
objectClass: pwdPolicy
objectClass: person
objectClass: top
pwdAllowUserChange: TRUE
pwdAttribute: userPassword
pwdCheckQuality: 2
pwdExpireWarning: 600
pwdFailureCountInterval: 30
pwdGraceAuthNLimit: 5
pwdInHistory: 5
pwdLockout: TRUE
pwdLockoutDuration: 0
pwdMaxAge: 0
pwdMaxFailure: 5
pwdMinAge: 0
pwdMinLength: 5
pwdMustChange: FALSE
pwdSafeModify: FALSE
sn: dummy value
EOF
}

### create and configure directory trees

# remove directory tree and database
#remove_tree()
#{
	# search for directory on tree index
	
	# remove database directory
	# ldapsearch -H ldapi:/// -Y EXTERNAL -Q -b 'cn=config' '(olcSuffix=dc=inces,dc=gob,dc=ve)'
	# remove config file
#}

create_tree()
{
	# create directory for database
	if [ ! -d "$DB_DIRECTORY" ]; then
		mkdir -p $DB_DIRECTORY
	fi
	
	chmod 755 $DB_DIRECTORY
	chown $LDAP_USER:$LDAP_GROUP $DB_DIRECTORY -R
	# add olcDatabase
	
	# populate tree with Basic Tree LDIF
	
	# index tree
	
	# change owner
	chown $LDAP_USER:$LDAP_GROUP $DB_DIRECTORY -R
}

ssl_configure() {
# fix permissions
chown root.ssl-cert /etc/ssl -R
usermod -a -G ssl-cert openldap

$LDAPADD << EOF
dn: cn=config
changetype:modify
replace: olcLocalSSF
olcLocalSSF: 71
-
replace: olcTLSCACertificatePath
olcTLSCACertificatePath: /etc/ssl/certs
-
replace: olcTLSCACertificateFile
olcTLSCACertificateFile: /etc/ssl/certs/cacert.org.pem
-
replace: olcTLSCertificateFile
olcTLSCertificateFile: /etc/ssl/certs/ssl-cert-snakeoil.pem
-
replace: olcTLSCertificateKeyFile
olcTLSCertificateKeyFile: /etc/ssl/private/ssl-cert-snakeoil.key
-
replace: olcTLSCRLCheck
olcTLSCRLCheck: none
-
replace: olcTLSVerifyClient
olcTLSVerifyClient: allow 
-
replace: olcTLSCipherSuite
olcTLSCipherSuite: +RSA:+AES-256-CBC:+SHA1
EOF
}

sasl_configure() 
{
	info "Configuring SASL with openLDAP"
# configuramos e iniciamos saslauthd
sed -i 's/START=no/START=yes/g' /etc/default/saslauthd
sed -i "s/MECHANISMS=.*$/MECHANISMS=\"ldap pam\"/g" /etc/default/saslauthd

# configuramos saslauthd
cat <<EOF > /etc/saslauthd.conf
ldap_servers: ldap://$SERVERNAME/
ldap_auth_method: bind
ldap_bind_dn: cn=admin,$BASE_DN
ldap_bind_pw: $PASS
ldap_version: 3
ldap_search_base: $BASE_DN
ldap_filter: (uid=%U)
ldap_verbose: on
ldap_scope: sub
 #SASL info
ldap_default_realm: $DOMAIN
ldap_use_sasl: no
ldap_debug: 3
EOF

chmod 640 /etc/saslauthd.conf

# reiniciamos el servicio
/etc/init.d/saslauthd restart

# configuramos SASL en openLDAP:
$LDAPADD << EOF
dn: cn=config
changetype:modify
replace: olcPasswordHash
olcPasswordHash: {SSHA}
-
replace: olcSaslSecProps
olcSaslSecProps: noplain,noanonymous,minssf=56
-
replace: olcAuthzPolicy
olcAuthzPolicy: none
-
replace: olcConnMaxPendingAuth
olcConnMaxPendingAuth: 1000
-
replace: olcSaslHost
olcSaslHost: $SERVERNAME
-
replace: olcSaslRealm
olcSaslRealm: $DOMAIN
EOF

# configuramos SASL en la DB
$LDAPADD << EOF
dn: cn=config
changetype: modify
replace: olcAuthzRegexp
olcAuthzRegexp: uid=(.*),cn=.*,cn=.*,cn=auth ldap:///??sub?(uid=$1)
EOF

# verificamos el acceso a los mecanismos SASL
echo
echo " Verificando acceso a todos los mecanismos SASL "
echo
$LDAPSEARCH -x -b '' -s base -LLL supportedSASLMechanisms
if [ "$?" -ne "0" ]; then
   echo "Error: acceso a los mecanismos SASL, alto"
   exit 1
fi
}

schema_configure() {
info "Loading basic schemas (namedObject and Password Policies)"
datadir
# copiamos los nuevos esquemas
cp $DATADIR/schemas/* $LDAP_DIRECTORY/cn\=config/cn\=schema/
# asignar el propietario y grupo:
chown $LDAP_USER:$LDAP_GROUP $LDAP_DIRECTORY -R
}

### DIT functions

load_basic_dit()
{
	# load a basic dit for a simple ldap tree
	datadir
	dit="$DATADIR/database/basicdit.ldif"
	
	debug "loading basic Directory information Tree"

$LDAPADDUSER -c -D "$CN_ADMIN" -w "$PASS" << EOF
$(template $dit)
EOF
}

tree_indexing()
{
	IDX=$@
# e indexamos
$LDAPADD << EOF
dn: olcDatabase={$IDX}$BACKEND,cn=config
changetype: modify
replace: olcDbIndex
olcDbIndex: objectClass eq
olcDbIndex: uid eq,approx,sub
olcDbIndex: telephoneNumber eq,sub,pres
olcDbIndex: uidNumber,gidNumber,memberUid,loginShell eq
#indice para entradas cn,ou,o,sn,uid
olcDbIndex: cn,sn,ou,o eq,pres,sub,subinitial
#indice para busqueda de nombres,apellidos, etc
olcDbIndex: givenname,displayName eq,subinitial,approx
olcDbIndex: employeeType,employeeNumber,l pres,eq
#indice para cuentas de correo
olcDbIndex: mail pres,eq,sub
# posixAccount
olcDbIndex: homeDirectory,gecos eq
#indice para NIS
olcDbIndex: nisMapName,nisMapEntry eq,pres,sub
# indice para replicacion
olcDbIndex: entryCSN,entryUUID pres,eq
EOF
}
