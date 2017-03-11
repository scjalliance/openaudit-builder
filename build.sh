#!/bin/bash

# usage probably something like this:
# ./build.sh all ../openaudit %V%
#    ... or ...
# ./build.sh 1.12.10.1 ../openaudit %V%
# where ../openaudit is the scjalliance/openaudit repo

function __oae.Usage {
	echo ""
	echo "usage: $0 <version> [destination]"
	echo ""
	echo "  version:     'all' means to build all versions listed in versions.txt"
	echo "               '1.2.3' means to build only version '1.2.3' (for example)"
	echo ""
	echo "  destination: If version==all, where the build directories will go (subdir created per version)"
	echo "               If version!=all, where the single build will go (no subdir created)"
	echo "               If version==all and gitbranch is defined, this dir is the root of the git repo instead"
	echo "               If omitted, destination is parent directory"
	echo ""
	echo "  gitbranch:   Name of the git branch to use, if you wish to use git branches and have this script"
	echo "               manage them.  If omitted, no git handling will be done at all."
	echo "               If defined, destination must also be defined."
	echo "               The string '%V%' will be replaced with the version value."
	echo ""
}

function __oae.Build {
	local S="$1"
	local V="$2"
	local D="$3"
	local B="$4"
	pushd "$D" >/dev/null
	local BRANCHSTATE="$(git branch --list "$B" | grep "$B" && echo EXISTS)"
	if [ ! -z "$B" ]; then
		git branch | grep -e "\b$B\b"
		git checkout -b "$B" master || git checkout -f "$B"
		if [ "$(git rev-parse --abbrev-ref HEAD)" != "$B" ]; then
			echo "NOT IN EXPECTED BRANCH"
			return
		fi
		git reset --hard
		git clean -df
		git checkout -- .
	fi
	cat "$S/Dockerfile" | sed "s/%VERSION%/$V/g" > Dockerfile
	cp -a "$S/run.sh" run.sh
	rm -f build.okay
	docker build -t "scjalliance/openaudit:$V" . && touch build.okay
	if [ ! -z "$B" -a "$(git rev-parse --abbrev-ref HEAD)" == "$B" ]; then
		if [ -f build.okay ]; then
			git add .
			git commit -m "Build $V via build.sh"
		else
			git reset --hard
			git clean -df
			git checkout -- .
			if [ "$BRANCHSTATE" != "EXISTS" ]; then
				# this branch didn't exist until now, so we will not keep it around
				git checkout -f master
				git branch -D "$B"
			fi
		fi
		git checkout -f master
	fi
	popd >/dev/null
}

function __oae.PrepAndBuild {
	local S="$1"
	local V="$2"
	local D="$3"
	local B="$4"
	if [ -z "$S" -o -z "$V" -o -z "$D" ]; then
		echo "Source directory, version number, or destination directory is not specified.  Aborting."
		echo -e "S=$S\nV=$V\nD=$D\nB=$B"
		__oae.Usage
		exit 1
	fi
	B="$(echo "$B" | sed "s/%V%/$V/g")"
	echo "$V = $D ($B)"
	mkdir -p "$D"
	__oae.Build "$S" "$V" "$D" "$B"
}

##### start...

if [ "$1" == "-h" -o "$1" == "help" ]; then
	__oae.Usage
	exit 1
fi

S="$(readlink -f "$(dirname "$0")")"
V="$1"
D="$2"
B="$3"

if [ -z "$V" ]; then
	echo "You must supply either 'all' or the version number to build, such as '1.12.10', as the first argument."
	__oae.Usage
	exit 1
else
	if [ ! -z "$B" -a -z "$D" ]; then
		echo "If gitbranch is defined, destination must also be defined.  If you want localdir, use . instead."
		__oae.Usage
		exit 1
	fi
	if [ "$V" == "all" ]; then
		cat versions.txt | tac | while read Vi; do
			Di="$(readlink -m "${D:-$S/..}/$Vi")"
			[ ! -z "$B" ] && Di="$(readlink -m "$D")"
			__oae.PrepAndBuild "$S" "$Vi" "$Di" "$B"
		done
	else
		Di="${D:-$(readlink -m "$S/../$V")}"
		[ ! -z "$B" ] && Di="$(readlink -m "$D")"
		__oae.PrepAndBuild "$S" "$V" "$Di" "$B"
	fi
fi
