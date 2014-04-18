EASY LDAP (ELDAP) v2.0
======================

EASY LDAP permite una fácil implementación de openldap en servidores GNU/Linux Debian y derivados.

Provee instalación y post-configuración automatizada para:

* openLDAP
* Bosque de dominios
* Cifrado SASL y Seguridad TLS/SSL
* Activación de módulos y overlays

Además, permite la posterior instalación y configuración de:

* Esquemas y módulos asociados
* Nuevos árboles LDAP
* Anillos de Claves (SSH-keys, GNUPG y x.509)
* Replicación (syncprov)

Entre las características soportadas actualmente:

easy-ldap v2.0

* Soporte para MDB (Lightning Database LMDB), con soporte MVCC, multi-threaded y memory-based, blazing fast!
* Soporte para múltiples servicios (DNS bind, ISC DHCP, Samba > 3.4, etc)
* Comandos integrados para conversión/instalación de schemas
* Soporte para un openPGP keyserver
* Soporte para sudo-ldap y autenticación PAM
* Soporte para definición de impresoras CUPS
* Replicación Maestro-Esclavo y MirrorMode


Requerimientos
--------------

Para cada árbol LDAP se requiere simplemente:

Dominio:       example.com
Sufijo LDAP:   dc=example,dc=com (construido a partir del dominio)
Clave de Administrador: <clave del cn=admin del LDAP> (solicitado de manera interactiva o generado aleatoriamente)

Dominio y base DN serán obtenidos a partir de la configuración del sistema (hostname --fdqn)

El script instala todos los requerimientos, pero inicialmente necesita:

* ldap-utils
* python-ldap

Módulos de Aplicaciones
-----------------------

Las siguientes aplicaciones ya tienen configuración conectada a ELDAP:

* ssh-keys en LDAP
* PAM y NSS LDAP
* sudo-ldap
* kerberos-ldap
* Anillo gnupg
* Samba
* isc-DHCP-ldap
* Asterisk
* FreeRadius

Y otros módulos conectores adicionales.
