#!/bin/bash

# prueba de un templating system

DOMAIN='devel.local'
DC=devel
BASE_DN='dc=devel,dc=local'

DIT="/home/jesuslara/proyectos/eldap/data/database/dit.ldif"

shtemplate()
{
	# loading a template
	file=$@
	if [ -f "$file" ]; then
	eval "cat <<EOF
$(<${file})
EOF
" 2> /dev/null
	fi
}

template()
{
	file=$@
	while read -r line ; do
		line=${line//\"/\\\"}
		line=${line//\`/\\\`}
		line=${line//\$/\\\$}
		line=${line//\\\${/\${}
		eval "echo \"$line\"";
	done < "${file}"
}

MESSAGE=$(cat << _MSG
$(template $DIT)
_MSG
)

var="$(template $DIT)"

echo "$var"


