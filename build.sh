#!/bin/bash

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
	echo ""
}

function __oae.Build {
	local S="$1"
	local V="$2"
	local D="$3"
	local B="$4"
	cat Dockerfile | sed "s/%VERSION%/$V/g" > "$D/Dockerfile"
	cp -a run.sh "$D/run.sh"
	pushd "$D" >/dev/null
	[ -z "$B" ] && (git checkout -b "$B" master || git checkout -f "$B") && git reset --hard || exit 1
	rm -f build.okay
	docker build -t "scjalliance/openaudit:$V" . | tee build.log && touch build.okay
	[ -f build.okay && -z "$B" ] && git add . && git commit -a -m "Build $V via build.sh"
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
	if [ ! -z "$B" && -z "$D" ]; then
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