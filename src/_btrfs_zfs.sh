#! /bin/sh

set -u

# XXX can't getopt the arguments of a function!
# XXX ERROR: can't snapshot $vol: EROFS => snapshots too close in time (one MINUTE...)
#     It happens when debugging - run too often...

readonly SnapDir=.btrfs/snapshots # XXX btrfs NEEDS something like .zfs!!!

# foo@bar => SUBV=foo SNAP=bar
_parseat() {
		case "$1" in
			(*@*@*) echo "$0 two '@' in ($1)???" >&2; exit 100;;
			(*@*) ;;
			(*) echo >&2 "($1) must be <mountpoint>@<snapshotname>"; exit 100;;
		esac
		SUBV="${i%%@*}"
		SNAP="${i##*@}"
}

blah() {
	logger "$0: $*"
}

silently() {
	# zfs snapshot is silent, btrfs is __always__ noisy...
	stfu="$( "$@" 2>&1)" && return
	crap=$?
	echo >&2 "$0 $* -- $stfu"
	return $crap
}

#zfs	destroy	-d	-r	poolname@zfs-auto-snap_frequent-2022-01-08-1415
destroy() {
	dflag= # destroy immediately or "mark it" for later...
	rflag= # recursive
	while getopts "dr" option ; do
		case "$option" in
			(d) dflag=d ;;
			(r) rflag=r ;;
			(*) exit 100 ;;
		esac
	done
	# Ignored (for now?)
	: "$dflag - Destroy immediately. If a snapshot cannot be destroyed now, mark it for deferred destruction."
	: "$rflag - Destroy (or mark for deferred deletion) all snapshots with this name in descendent file systems."
	shift $((OPTIND - 1))
	test $# -gt 0 || { echo >&2 "$0: destroy what?"; exit 100; }
	for i in "$@" ; do
		_parseat "$i"
		test -d "$SUBV"/"$SnapDir" || { ls -l "$SUBV/$SnapDir" >&2; exit 100; }
		blah "destroy $i"
		silently btrfs subvolume delete "$SUBV/$SnapDir/$SNAP" ; exit 111 || exit
	done
}

#zfs	snapshot	-o	com.sun:auto-snapshot-desc=-	-r	poolname@zfs-auto-snap_frequent-2022-01-11-1920
snapshot() {
	properties= # btrfs-property(8) is UNUSABLE, it only has a FIXED set of properties
	recursive=
	while getopts "o:r" option ; do
		case "$option" in
			(o)
				properties="$OPTARG"
				true "$OPTARG" ;; # TODO btrfs properties?
			(r)
				recursive=y # we rely on list listing everything; 100% atomic...
				true ;;
			(*) exit 100 ;;
		esac
	done
	shift $((OPTIND - 1))
	test $# -gt 0 || { echo >&2 "$0: snapshot what?"; exit 100; }
	true "$properties $recursive" # shut up shellcheck
	for i in "$@" ; do
		blah "snap: _parseat $i"
		_parseat "$i"
		blah "snap: SNAP=$SNAP"
		test -d "$SUBV"/"$SnapDir" || mkdir -p "$SUBV/$SnapDir" || exit
		silently btrfs subvolume snapshot -r "$SUBV" "$SUBV/$SnapDir/$SNAP" || exit
	done
}

#zfs	list	-H	-t	filesystem,volume	-s	name	-o	name,com.sun:auto-snapshot,com.sun:auto-snapshot:daily
#zfs	list	-H	-t	snapshot	-S	creation	-o	name
#zfs	list	-H	-t	filesystem,volume	-s	name	-o	name,com.sun:auto-snapshot,com.sun:auto-snapshot:weekly
#zfs	list	-H	-t	filesystem,volume	-s	name	-o	name,com.sun:auto-snapshot,com.sun:auto-snapshot:monthly
#zfs	list	-H	-t	filesystem,volume	-s	name	-o	name,com.sun:auto-snapshot,com.sun:auto-snapshot:frequent
#zfs	list	-H	-t	filesystem,volume	-s	name	-o	name,com.sun:auto-snapshot,com.sun:auto-snapshot:hourly
#TODO some way (file in $SnapDir?) to turn snapshots off for a subvolume! (no zfs properties)
#Think of /var/tmp, /var/cache, ...
list() {
	Hflag=
	types=
	Sflag= # same as -s except sorted in reverse
	sortoption= # -s/-S; for printing errors.
	sortkey= # for -s
	properties= # to display
	while getopts ":Ht:o:S:s:" option ; do
		case "$option" in
			(H) Hflag=true ;;
			(s) Sflag= ; sortoption=-s; sortkey="$OPTARG";;
			(S) Sflag=true ; sortoption=-S; sortkey="$OPTARG";;
			(t) types="$OPTARG" ;;
			(o) properties="$OPTARG" ;;
			(*) exit 100 ;;
		esac
	done
	shift $((OPTIND - 1))
	case $# in
		(0) ;;
		(*) echo >&2 "no arguments for $0 list"; exit 100;;
	esac
	: "$Hflag" # Hflag is ignored - we always output for computers, never humans.
	lsreverse=
	test -z "$Sflag" || lsreverse=-r
	lssort=
	case "$sortkey" in
		(name) lssort= ;; # ls sorts by default
		(creation) lssort=-t ;;
		(*)
			echo>&2 "$0 list($sortoption $sortkey) -- need -s/-S creation/name"
			exit 100
			;;
	esac
	if test _"$types" = _"filesystem,volume" ; then
		# XXX won't bother sorting
		mount | awk '$5 == "btrfs" { print $3 }' | while read -r m ; do printf '%s\t-\t-\n' "$m" ; done
		return
	fi
	if ! test _"$types" = _"snapshot" ; then
		echo >&2 "$0 $* -- either filesystem,volume or snapshot"
		exit 100
	fi
	# XXX btrfs subvolume can list => pipe/xargs to ls for order
	# XXX BUT it also lists subvolumes, not just snapshots! => -s
	# btrfs subvolume list -s /var/tmp
	#ID 258 gen 41 cgen 41 top level 5 otime 2022-01-12 23:31:56 path snap-test
	# no obvious way to get just the path...
	#list of: poolname@snapshot
	mount | awk '$5 == "btrfs" { print $3 }' | while read -r vol ; do
	( test -d "$vol/$SnapDir" || exit 0
	cd "$vol/$SnapDir" || exit
	# shellcheck disable=SC2012
	# I need ls's sorting flags
	ls $lssort $lsreverse -- | while read -r i ; do btrfs subvol show "$i" >/dev/null && echo "${vol}@${i}" ; done
	)
	done
}

test $# -gt 0 || { echo >&2 "no arguments for $0?"; exit 100; }

cmd="$1"
shift
case "$cmd" in
	(list) list "$@" ;;
	(destroy) destroy "$@" ;;
	(snapshot) snapshot "$@" ;;
	(*)
		echo >&2 "$0($*)???"
		exit 100
		;;
esac
