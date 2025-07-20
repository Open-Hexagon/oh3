#!/bin/sh
for var in "$@"
do
	soname=$(echo "$var" | cut -d ":" -f 1)
	file=$(echo "$var" | cut -d ":" -f 2)
	echo -n "{\"$soname\",(namedp[]){"
	emnm --quiet -gU "$file" | awk '{ if ($3 != "" && !match($3, "^_Z")) printf "{\"" $3 "\",(void*) &" $3 "}," }'
	echo -n "{ NULL, NULL }}},"
done
