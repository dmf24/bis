#!/bin/bash

export SOURCES=${SOURCES:-$HOME/src}
export MODULESLIB=${MODULESLIB:-/etc/profile.d/modules.sh}
export BIS_BUILD=${BIS_BUILD:-$HOME/.bis/build}
export WORKSPACE_ROOT=${WORKSPACE_ROOT:-$BIS_BUILD/workspace}
export INSTALL_ROOT=${INSTALL_ROOT:-$HOME/opt}

export src_extensions="tar.gz tgz zip tar.bz2 tar.xz"

bstype () {
    # Check filename and determine whether it's an rpmbuild spec file
    # or a bis file
    filename=$1
    if [ "${filename: -5}" = ".spec" ]
    then
	echo spec
	return 0
    elif [ "${filename: -4}" = ".bis" ]
    then
	echo bis
	return 0
    fi
}
export -f bstype

setnamevers () {
    # Assign first 3 name/version pairs to
    # variables for convenience
    export NAME_ARRAY=( $@ )
    export NAME=$1
    export NAME1=$1
    shift
    export VERSION=$1
    export VERSION1=$1
    shift
    export NAME2=$1
    shift
    export VERSION2=$1
    shift
    export NAME3=$1
    shift
    export VERSION3=$1
    shift
}
export -f setnamevers

bis-description () {
    # Reads a HEREDOC argument into the DESCRIPTION variable.
    IFS='\n' read -r -d '' DESCRIPTION || true;
}
export -f bis-description

parsevars () {
    filename=$1
    export FULLNAME=${filename%.*}
    export WORKSPACE=${WORKSPACE:-$WORKSPACE_ROOT/$FULLNAME}
    export ARGS_TO_PASS=$(echo $FULLNAME | cut -f-999 -d'-' --output-delimiter=' ')
    setnamevers $ARGS_TO_PASS
}
export -f parsevars

archive-type () {
    FILENAME=$1
    test "${FILENAME: -4}" = ".tar" && ARCHIVE=tar
    test "${FILENAME: -4}" = ".tgz" && ARCHIVE=targz
    test "${FILENAME: -4}" = ".zip" && ARCHIVE=zip
    test "${FILENAME: -7}" = ".tar.gz" && ARCHIVE=targz
    test "${FILENAME: -7}" = ".tar.xz" && ARCHIVE=tarxz
    test "${FILENAME: -8}" = ".tar.bz2" && ARCHIVE=tarbz2
    echo $ARCHIVE
}
export -f archive-type

# zipinfo -1
# tar -ztf
# bunzip2 -c $1 | tar t
bis-determine-unpackdir () {
    S=$1
    ARCHIVE_TYPE=$(archive-type $S)
    case $ARCHIVE_TYPE in
	tar)
	    filelist="$(tar -tf $S)"
	    ;;
	targz)
	    filelist="$(tar -ztf $S)"
	    ;;
	zip)
	    filelist="$(zipinfo -1 $S)"
	    ;;
	tarbz2)
	    filelist="$(bunzip2 -c $S | tar -t)"
	    ;;
	tarxz)
	    filelist="$(xzcat $S | tar -t)"
	    ;;
    esac
    unpackdir="$(echo $filelist | cut -f1 -d'/' | sort -u)"
    if [ "$(echo \"$unpackdir\" | wc -w)" != "1" ]
    then
	return 0
    else
	echo $unpackdir
    fi
}
export -f bis-determine-unpackdir

bis-unarchive () {
    S=$1
    workdir=$2
    ARCHIVE_TYPE=$(archive-type $S)
    echo "Unarchiving $S ($ARCHIVE_TYPE) to workdir: $workdir"
    cd $workdir
    echo "# archive type: $ARCHIVE_TYPE"
    case $ARCHIVE_TYPE in
	tar)
	    tar -xf $S
	    ;;
	targz)
	    tar -zxf $S
	    ;;
	zip)
	    unzip $S
	    ;;
	tarbz2)
	    bunzip2 -c $S | tar -x
	    ;;
	tarxz)
	    xzcat $S | tar -x
	    ;;
    esac
}
export -f bis-unarchive

bis-set-unpack-path () {
    updir=$(bis-determine-unpackdir $SOURCE)
    if test -n "$updir"
    then
	export UNPACKPATH=$WORKSPACE/$updir
    else
	export UNPACKPATH=$WORKSPACE
	echo "WARNING: archive does not appear to unpack to a single directory" >&2
	echo "         Setting unpack path to $WORKSPACE" >&2
    fi
}
export -f bis-set-unpack-path

bis-verify () {
    test -z "$SOURCE" && echo WARNING: SOURCE not set
    test -z "$WORKSPACE" && echo WARNING: WORKSPACE not set
    test -z "$INSTALL_DIR" && echo WARNING: INSTALL_DIR not set
    test -z "$INSTALL_ROOT" && echo WARNING: INSTALL_ROOT not set
    test -f "$SOURCE" || echo WARNING: source package $SOURCE does not exist

}
export -f bis-verify

bis-show-vars () {
    test -n "$SOURCE_FILENAME" && echo "SOURCE_FILENAME=$SOURCE_FILENAME"
    test -n "$SOURCE" && echo "SOURCE=$SOURCE"
    test -n "$SOURCE_URL" && echo "SOURCE_URL=$SOURCE_URL"
    test -n "$INSTALL_ROOT" && echo "INSTALL_ROOT=$INSTALL_ROOT"
    test -n "$INSTALL_DIR" && echo "INSTALL_DIR=$INSTALL_DIR"
    test -n "$WORKSPACE" && echo "WORKSPACE=$WORKSPACE"
    test -n "$WORKSPACE_ROOT" && echo "WORKSPACE_ROOT=$WORKSPACE_ROOT"
    test -n "$UNPACKPATH" && echo "UNPACKPATH=$UNPACKPATH"
    test -n "$FULLNAME" && echo "FULLNAME=$FULLNAME"
    test -n "$NAME" && echo "NAME=$NAME"
    test -n "$VERSION" && echo "VERSION=$VERSION"
    test -n "$NAME2" && echo "NAME2=$NAME2"
    test -n "$VERSION2" && echo "VERSION2=$VERSION2"
    test -n "$NAME3" && echo "NAME3=$NAME3"
    test -n "$VERSION3" && echo "VERSION3=$VERSION3"
    #echo "BIS_BUILD=$BIS_BUILD"
    #echo "MODULESLIB=$MODULESLIB"
    #echo "src_extensions=$src_extensions"
    return 0
}
export -f bis-show-vars

bis-init () {
    export INSTALL_DIR=${INSTALL_DIR:-$INSTALL_ROOT/$NAME/$VERSION}
    for ex in $src_extensions
    do
	test -f $SOURCES/$NAME-$VERSION.$ex && EXT=$ex
    done
    DEFAULT_SOURCE_FILENAME=$NAME-$VERSION.$EXT
    export SOURCE_FILENAME=${SOURCE_FILENAME:-$DEFAULT_SOURCE_FILENAME}
    export SOURCE=${SOURCE:-$SOURCES/$SOURCE_FILENAME}
    test -z "$UNPACKPATH" && bis-set-unpack-path
    bis-verify
    echo "bis-init says: $1"
    if [ "$1" != "no-cd-to-workspace" ]
    then
	echo "test -d $WORKSPACE || mkdir -p $WORKSPACE"
	test -d "$WORKSPACE" || mkdir -p $WORKSPACE
	cd $WORKSPACE && echo "# Changed CWD to $WORKSPACE"
	echo "$(pwd)"
    fi
}
export -f bis-init

bis-clean () {
    if [ "$1" = "just-make-clean" ]
    then
	cd $UNPACKPATH
	make clean
    else
	echo "DEBUG:" rm -rf $UNPACKPATH
	rm -rf $UNPACKPATH
    fi
}
export -f bis-clean

bis-unpack () {
    bis-clean $1
    echo "unarchiving $SOURCE"
    bis-unarchive $SOURCE $WORKSPACE
    cd $UNPACKPATH
}
export -f bis-unpack

bis-finish () {
    # Add an application summary file and append
    CURRENT_TIME_LONG=$(date +"%a %b %d %Y")
    CURRENT_TIME_1STR=$(date +"%Y-%b-%d-%H:%M")
    test -n "$BUILD_OWNER" && BUILD_OWNER_PARENS="($BUILD_OWNER)"
    echo "$SUMMARY" > $INSTALL_DIR/bis-install.txt
    echo "$SOURCE_URL" >> $INSTALL_DIR/bis-install.txt
    echo "$DESCRIPTION" >> $INSTALL_DIR/bis-install.txt
    echo "${CURRENT_TIME_1STR}: Installed from $SOURCE via $FULLNAME.bis $BUILD_OWNER_PARENS" >> $INSTALL_DIR/bis-install.log
}
export -f bis-finish

fpath=$1
fname=$(basename $fpath)
BS_TYPE=$(bstype $fname)

if [ "$BS_TYPE" = "bis" ]
then
   parsevars $fname
   bash $fpath $ARGS_TO_PASS
fi
