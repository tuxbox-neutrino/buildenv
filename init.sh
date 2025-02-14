#!/bin/bash
source init.functions.sh
#set -x

## Comatible and default image version
DEFAULT_IMAGE_VERSION="3.2.4"
COMPATIBLE_IMAGE_VERSIONS="$DEFAULT_IMAGE_VERSION 3.2"
IMAGE_VERSION="$DEFAULT_IMAGE_VERSION"

## global vars
BASEPATH=$(pwd)
SSH=$(which ssh)
GIT_SSH_KEYFILE=""
true="1"
false="0"
DO_UPDATE=$false
DO_RESET=$false
FILES_DIR="$BASEPATH/files"
UPDATE_SERVER_URL="http://localhost"
DIST_DIR="$BASEPATH/dist"
USER_CALL="$0 $@"

## Basename of this script
NAME=$(basename $0)

## Timestamp for logging
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
## Logfile
LOG_PATH=$BASEPATH/log
mkdir -p $LOG_PATH
TMP_LOGFILE="$LOG_PATH/.$0-tmp.log"
rm -f $TMP_LOGFILE
LOGFILE_NAME="$NAME"_"$TIMESTAMP.log"
LOGFILE=$LOG_PATH/$LOGFILE_NAME
LOGFILE_LINK=$LOG_PATH/$NAME.log
LOCAL_CONFIG_FILE_INC_PATH=$BASEPATH/local.conf.common.inc
echo "" >  $LOGFILE
ln -sf $LOGFILE $LOGFILE_LINK
my_echo "true" "$USER_CALL"

## Current build env script version
BUILD_ENV_VERSION=$(git -C $BASEPATH describe --tags 2>/dev/null)
if [ -z "$BUILD_ENV_VERSION" ]; then
	BUILD_ENV_VERSION="unknown"
fi

## Machines
# Identical listings
MACHINES_IDENTICAL_HD51="hd51 ax51 mutant51"
MACHINES_IDENTICAL_H7="h7 zgemmah7"
MACHINES_IDENTICAL_HD60="hd60 ax60" #TODO: move into gfutures
MACHINES_IDENTICAL_HD61="hd61 ax61" #TODO: move into gfutures

# gfutures listing
MACHINES_GFUTURES="$MACHINES_IDENTICAL_HD51 bre2ze4k"
# hisilcon listing  #TODO: move into gfutures
MACHINES_HISI="$MACHINES_IDENTICAL_HD60 $MACHINES_IDENTICAL_HD61"
# airdigital listing
MACHINES_AIRDIGITAL="$MACHINES_IDENTICAL_H7"
# edision listing
MACHINES_EDISION="osmio4k osmio4kplus"
# ceryon listing
MACHINES_CERYON="e4hdultra"

# valid machine list
MACHINES="$MACHINES_GFUTURES $MACHINES_HISI $MACHINES_AIRDIGITAL $MACHINES_EDISION $MACHINES_CERYON"

MACHINE="all" # default for MACHINE, if not set
HINT_MACHINES="Select a valid machine type (empty means <all> as default) <$MACHINES>"
 
## Backups
BACKUP_PATH=$BASEPATH/backups
mkdir -p $BACKUP_PATH
BACKUP_SUFFIX=bak

# meta-neutrino project URL:
PROJECT_URL="https://github.com/tuxbox-neutrino"

## Help
show_help() {
	if [[ $LANG == de_* ]]; then
        echo "Dieses Skript initialisiert und aktualisiert die Entwicklungsumgebung für den Bau von Images und Paketen für verschiedene Maschinenkonfigurationen."
        echo "Es klont und aktualisiert Meta-Layer aus vorgegebenen Repositories, bereitet die Build-Umgebung vor und unterstützt die Konfiguration für spezifische Maschinentypen."
	else
        echo "This script initializes and updates the development environment for building images and packages for various machine configurations."
        echo "It clones and updates meta-layers from specified repositories, prepares the build environment, and supports configuration for specific machine types."
	fi
	echo ""
    echo "Usage: $0 [OPTIONS]..."
    echo ""
    echo "Options:"
    echo "  -m, --machine             $HINT_MACHINES"
    echo "      --update-url          URL (IP, hostname or domain, optional with portnumber) to define the update server address for $LOCAL_CONFIG_FILE_INC_PATH, default: $UPDATE_SERVER_URL"
    echo "      --dist-dir            Directory where to find the deployed images and packages, default: $DIST_DIR"
    echo "  -p, --project-url         Project-URL where to find project meta layers,"
    echo "                            e.g. for read and write access: git@github.com:tuxbox-neutrino, default = $PROJECT_URL"
    echo "      --image-version       Sets the required image version to build, possible versions are: $COMPATIBLE_IMAGE_VERSIONS, default = $DEFAULT_IMAGE_VERSION"
    echo "  -u, --update              Update your project meta layers"
    echo "  -r, --reset               Resets the tmp dir within the build directory, $BASEPATH/poky-x.x.x/build/<machine>/tmp. The /tmp directory will be not deleted but renamed"
    echo "  -i, --id-rsa-file         Path to your preferred id rsa file, default: users id rsa file, e.g. $HOME/.ssh/id_rsa"
    echo ""
    echo "  -h, --help                Show this help"
    echo "      --version             Show version information for buildenv script"
}

## Processing command line arguments
TEMP=$(getopt -o rup:m:i:h --long reset,update-url:,dist-dir:,update,project-url:,machine:,id-rsa-file,image-version:,help,version -n 'init' -- "$@")
if [ $? != 0 ] ; then
	my_echo "Error while process arguments" >&2
	show_help
	exit 1
fi

# Note the quotes around `$TEMP`: they are essential!
eval set -- "$TEMP"

# Extract arguments.
while true ; do
    case "$1" in
        -p|--project-url)
            PROJECT_URL="$2"; shift 2 ;;
        -m|--machine)
            MACHINE="$2"; shift 2 ;;
		-i|--id-rsa-file)
            GIT_SSH_KEYFILE="$2"; shift 2 ;;
		   --update-url)
            UPDATE_SERVER_URL="$2"; shift 2 ;;
		   --dist-dir)
            DIST_DIR="$2"; shift 2 ;;
		-u|--update)
			DO_UPDATE="$true"; shift ;;
		-r|--reset)
			DO_RESET="$true"; shift ;;
          --image-version)
            IMAGE_VERSION="$2"; shift 2 ;;
        -h|--help)
            show_help
            exit 0 ;;
		  --version)
		    echo "$BUILD_ENV_VERSION"
		    exit 0 ;;
        --) shift ; break ;;
        *) echo "Internal Error!" ; exit 1 ;;
    esac
done

## Validate the chosen image version
if [[ ! " $COMPATIBLE_IMAGE_VERSIONS " =~ " $IMAGE_VERSION " ]]; then
    my_echo "\033[31;1mError: Invalid image version specified '$IMAGE_VERSION'. Available versions are: [$COMPATIBLE_IMAGE_VERSIONS]\033[0m"
    exit 1
fi

## Layer sources
YOCTO_GIT_URL="https://git.yoctoproject.org/git/poky"
POKY="$(basename $YOCTO_GIT_URL)"
POKY_NAME="$IMAGE_VERSION" #TODO
BUILD_ROOT_DIR="$BASEPATH/$POKY-$IMAGE_VERSION"
BUILD_ROOT="$BUILD_ROOT_DIR/build"

OE_LAYER_NAME=meta-openembedded
OE_LAYER_GIT_URL=https://git.openembedded.org/meta-openembedded
OE_LAYER_PATCH_LIST=""

OE_CORE_LAYER_NAME=openembedded-core
OE_CORE_LAYER_GIT_URL=https://github.com/openembedded/openembedded-core.git

## Preset required branches and revs based on the selected image version
case "$IMAGE_VERSION" in
    "3.2"|"3.2.4")
        COMPATIBLE_TAG="$IMAGE_VERSION"
        COMPATIBLE_BRANCH="gatesgarth"
        YOCTO_SRCREV="bc71ec0"
        PYTHON2_SRCREV="27d2aeb"
        OE_SRCREV="f3f7a5f"
		OE_LAYER_PATCH_LIST="0001-openembedded-disable-meta-python.patch 0002-openembedded-disable-openembedded-layer-meta-phyton.patch"
        ;;
    *)
        my_echo "\033[31;1mError: No valid configuration for the specified image version '$IMAGE_VERSION'.\033[0m"
        exit 1
        ;;
esac

# Check machine type
if [ $(is_valid_machine "$MACHINE") == false ]; then
    my_echo "\033[31;1mNo valid machine defined.\033[0m"
    my_echo "$HINT_MACHINES"
    exit 1
fi

my_echo "------------------------------------------------------------------------------------------"
my_echo "Buildenv Version:          \033[37;1m$BUILD_ENV_VERSION\033[0m "
my_echo "Image Version:             \033[37;1m$IMAGE_VERSION\033[0m "
my_echo "Compatible OE-branch:      \033[37;1m$COMPATIBLE_BRANCH\033[0m "
my_echo "Buildroot directory:       \033[37;1m$BUILD_ROOT_DIR\033[0m "
my_echo "Update Server URL:         \033[37;1m$UPDATE_SERVER_URL\033[0m "
my_echo "Dist directory:            \033[37;1m$DIST_DIR\033[0m "
my_echo "Configured Machine(s):     \033[37;1m$MACHINE\033[0m "
my_echo "Project Repository URL:    \033[37;1m$PROJECT_URL\033[0m "
my_echo "SRCREV Yocto:              \033[37;1m$YOCTO_SRCREV\033[0m "
my_echo "SRCREV OE:                 \033[37;1m$OE_SRCREV\033[0m "
my_echo "SRCREV Python2:            \033[37;1m$PYTHON2_SRCREV\033[0m "
my_echo "------------------------------------------------------------------------------------------"

## reset build
if [[ $DO_RESET == "$true" ]]; then
	do_reset "$MACHINES"
	exit 0
fi

## Fetch meta sources
# fetch required branch from yocto
fetch_meta "" $COMPATIBLE_BRANCH $YOCTO_GIT_URL $YOCTO_SRCREV $BUILD_ROOT_DIR

# fetch required branch from openembedded
fetch_meta "" $COMPATIBLE_BRANCH $OE_LAYER_GIT_URL $OE_SRCREV $BUILD_ROOT_DIR/$OE_LAYER_NAME "$OE_LAYER_PATCH_LIST"

# fetch required branch of oe-core from openembedded
fetch_meta "" master $OE_CORE_LAYER_GIT_URL "" $BUILD_ROOT_DIR/$OE_CORE_LAYER_NAME

# fetch required branch for meta-python2
if [[ -n "$PYTHON2_SRCREV" ]]; then
	PYTHON2_LAYER_NAME=meta-python2
	PYTHON2_LAYER_GIT_URL=https://git.openembedded.org/$PYTHON2_LAYER_NAME
	PYTHON2_PATCH_LIST="0001-local_conf_outcomment_line_15.patch"
	fetch_meta "" $COMPATIBLE_BRANCH $PYTHON2_LAYER_GIT_URL $PYTHON2_SRCREV $BUILD_ROOT_DIR/$PYTHON2_LAYER_NAME "$PYTHON2_PATCH_LIST"
fi

# fetch required branch for meta-qt5
QT5_LAYER_NAME=meta-qt5
QT5_LAYER_GIT_URL=https://github.com/meta-qt5/$QT5_LAYER_NAME
fetch_meta "" $COMPATIBLE_BRANCH $QT5_LAYER_GIT_URL "" $BUILD_ROOT_DIR/$QT5_LAYER_NAME

# fetch required branch from meta-neutrino
TUXBOX_LAYER_NAME="meta-neutrino"
TUXBOX_LAYER_BRANCH="master"
TUXBOX_LAYER_SRCREV="ffc1b65ec3cfd2c6bbd339d3ce201d6b39abd527"
TUXBOX_LAYER_GIT_URL="${PROJECT_URL}/$TUXBOX_LAYER_NAME.git"
fetch_meta "" $TUXBOX_LAYER_BRANCH $TUXBOX_LAYER_GIT_URL "$TUXBOX_LAYER_SRCREV" $BUILD_ROOT_DIR/$TUXBOX_LAYER_NAME
safe_dir="$BUILD_ROOT_DIR/$TUXBOX_LAYER_NAME"
if ! git config --global --get safe.directory | grep -qxF "$safe_dir"; then
	do_exec "git config --global --add safe.directory \"$safe_dir\""
fi

# fetch required branch from meta-airdigital
AIRDIGITAL_LAYER_NAME="meta-airdigital"
AIRDIGITAL_LAYER_BRANCH="master"
AIRDIGITAL_LAYER_SRCREV="ac8f769e35f839bbcf9c38d2b2b98513be907ac1"
AIRDIGITAL_LAYER_GIT_URL="$PROJECT_URL/$AIRDIGITAL_LAYER_NAME.git"
if [ "$MACHINE" == "all" ] || [ $(is_required_machine_layer "' $MACHINES_AIRDIGITAL '") == true ]; then
	fetch_meta "" $AIRDIGITAL_LAYER_BRANCH $AIRDIGITAL_LAYER_GIT_URL "$AIRDIGITAL_LAYER_SRCREV" $BUILD_ROOT_DIR/$AIRDIGITAL_LAYER_NAME
fi

# fetch required branch from meta-gfutures
GFUTURES_LAYER_NAME=meta-gfutures
GFUTURES_LAYER_BRANCH="master"
GFUTURES_LAYER_SRCREV="bfceb9d2f79a8403ce1bdf1ad14a1714f781fed3"
GFUTURES_LAYER_GIT_URL="$PROJECT_URL/$GFUTURES_LAYER_NAME.git"
if [ "$MACHINE" == "all" ] || [ $(is_required_machine_layer "' $MACHINES_GFUTURES '") == true ]; then
	# gfutures
	fetch_meta "" $GFUTURES_LAYER_BRANCH $GFUTURES_LAYER_GIT_URL "$GFUTURES_LAYER_SRCREV" $BUILD_ROOT_DIR/$GFUTURES_LAYER_NAME
fi

# fetch required branch from meta-ceryon
CERYON_LAYER_NAME=meta-ceryon
CERYON_LAYER_BRANCH="master"
CERYON_LAYER_SRCREV="4a02145fc4c233b64f6110d166c46b59ebe73371"
CERYON_LAYER_GIT_URL="$PROJECT_URL/$CERYON_LAYER_NAME.git"
if [ "$MACHINE" == "all" ] || [ $(is_required_machine_layer "' $MACHINES_CERYON '") == true ]; then
	fetch_meta "" $CERYON_LAYER_BRANCH $CERYON_LAYER_GIT_URL "$CERYON_LAYER_SRCREV" $BUILD_ROOT_DIR/$CERYON_LAYER_NAME
fi

# fetch required branch from meta-hisilicon #TODO: move into gfutures
HISI_LAYER_NAME=meta-hisilicon  #TODO: move into gfutures
HISI_LAYER_BRANCH="master"
HISI_LAYER_SRCREV="e85e1781704d96f5dfa0c554cf81d24c147d888c"
HISI_LAYER_GIT_URL="$PROJECT_URL/$HISI_LAYER_NAME.git"
if [ "$MACHINE" == "all" ] || [ $(is_required_machine_layer "' $MACHINES_HISI '") == true ]; then
	fetch_meta "" $HISI_LAYER_BRANCH $HISI_LAYER_GIT_URL "$HISI_LAYER_SRCREV" $BUILD_ROOT_DIR/$HISI_LAYER_NAME
fi

# fetch required branch from meta-edision
EDISION_LAYER_NAME=meta-edision
EDISION_LAYER_BRANCH="master"
EDISION_LAYER_SRCREV="1b2c422d9218e86ca1cd9d20431d42e716b1d714"
EDISION_LAYER_GIT_URL="$PROJECT_URL/$EDISION_LAYER_NAME.git"
if [ "$MACHINE" == "all" ] || [ $(is_required_machine_layer "' $MACHINES_EDISION '") == true ]; then
	fetch_meta '' $EDISION_LAYER_BRANCH $EDISION_LAYER_GIT_URL "$EDISION_LAYER_SRCREV" $BUILD_ROOT_DIR/$EDISION_LAYER_NAME
fi

## Configure buildsystem
# Create included config file from sample file
if test ! -f $LOCAL_CONFIG_FILE_INC_PATH; then
	my_echo "\033[37;1mCONFIG:\033[0mCreate $LOCAL_CONFIG_FILE_INC_PATH as include file for local layer configuration ..."
	do_exec "cp -v $LOCAL_CONFIG_FILE_INC_PATH.sample $LOCAL_CONFIG_FILE_INC_PATH"
	do_exec "sed -i -e 's|#UPDATE_SERVER_URL = \"http://@hostname@\"|UPDATE_SERVER_URL = \"${UPDATE_SERVER_URL}\"|' $LOCAL_CONFIG_FILE_INC_PATH"
fi

# Create configuration for machine
my_echo "\033[37;1mCreate configurations ...\033[0m"
if [ "$MACHINE" == "all" ]; then
	for M in  $MACHINES ; do
		create_local_config $M;
	done
	my_echo "\033[32;1mdone!\033[0m\n"
else
	create_local_config $MACHINE;
	my_echo "\033[32;1mdone!\033[0m\n"
fi

## Create distribution structure
create_dist_tree;

## Distribution directory inside httpd directory for online update
my_echo "\033[37;1mLocal setup for package online update.\033[0m"
my_echo "------------------------------------------------------------------------------------------------"
my_echo "If you want to use online update for your devices, please configure your webserver and use the"
my_echo "content of $DIST_DIR"
my_echo "as destination for your webserver (e.g. apache, nginx, lighttpd or what ever you want)"
my_echo ""

## Show results
my_echo "\033[32;1m\nSummary:\033[0m"
my_echo "\033[32;1m------------------------------------------------------------------------------------------------\033[0m"
my_echo ""
my_echo "\033[37;1mLocal environment setup was created\033[0m"
my_echo "------------------------------------------------------------------------------------------------"
my_echo "On 1st call of $0 Your config was created at this file from the template sample file"
my_echo ""
my_echo "\033[37;1m\t$BASEPATH/local.conf.common.inc\033[0m"
my_echo ""
my_echo "If this file has already exists some entries could be migrated or added on this file."
my_echo "You should check $BASEPATH/local.conf.common.inc and modify it if required."
my_echo ""
my_echo "Unlike here: Please check this files for modifications or upgrades:"
my_echo ""
my_echo "\033[37;1m\t$BUILD_ROOT/<machine>/bblayer.conf\033[0m"
my_echo "\033[37;1m\t$BUILD_ROOT/<machine>/local.conf\033[0m"

my_echo ""
my_echo "\033[37;1mUpdating build evironment and meta-layers\033[0m"
my_echo "------------------------------------------------------------------------------------------------"
my_echo ""
my_echo "\033[37;1m\texecute: $0\033[0m \033[32;1m--update\033[0m"
my_echo ""
my_echo "------------------------------------------------------------------------------------------------"

my_echo "\033[32;1mDONE!\033[0m"

my_echo ""
my_echo "\033[37;1mStart build\033[0m"
my_echo "------------------------------------------------------------------------------------------------"
my_echo "Now you are ready to build your own images and packages."
my_echo "Selectable machines are:"
my_echo ""
my_echo "\033[37;1m\t$MACHINES\033[0m"
my_echo ""
my_echo "Select your favorite machine (or identical) and the next steps are:\033[37;1m"
my_echo ""
my_echo "\tcd $BUILD_ROOT_DIR && . ./oe-init-build-env build/<machine>"
my_echo "\tbitbake neutrino-image"
my_echo "\033[0m"

my_echo "For more information and next steps take a look at the README.md!"

exit 0
