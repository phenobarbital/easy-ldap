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

	cn_config
	ldap_modules
	
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
olcModuleload: back_bdb
olcModuleload: back_mdb
olcModuleload: unique
olcModuleload: back_dnssrv
olcModuleload: back_ldap
olcModuleload: syncprov
olcModuleload: dynlist
olcModuleload: refint
olcModuleload: constraint
olcModuleload: back_monitor
olcModuleload: back_perl
olcModuleload: back_shell
olcModuleload: ppolicy
olcModuleload: accesslog
olcModuleload: auditlog
olcModuleload: valsort
olcModuleload: memberof
EOF
}
