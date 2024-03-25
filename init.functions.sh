#!/bin/bash

## Function to replace the echo command
function my_echo() {
	local no_term_output="$1"
	# Clean up text
	if [ "$no_term_output" == "true" ]; then
		shift
	fi
    local cleaned_output=$(echo -e "${@}" | sed -r "s/\x1B\[[0-9;]*[a-zA-Z]//g")
    # Write to log
    echo "[ $(date '+%Y-%m-%d %H:%M:%S') ] - ${cleaned_output}" >> "$LOGFILE"
    # Show on terminal
    if [[ "$no_term_output" != "true" && -t 1 ]]; then
        echo -e "${@}"
    fi
}

# function for checking of valid machine(s)
function is_valid_machine ()
{
	local ISM=$1
	for M in $MACHINES ; do
		if [ "$ISM" == "$M" ] || [ "$MACHINE" == "all" ]; then
			echo true
			return 1
		fi
	done
	echo false
	return 0
}

function do_exec() {
    local cmd="$1"
    local exit_behavior="$2"
    local show_output="$3"
    local log_text
    local cmd_exit_status

    my_echo true "[EXEC] $cmd"

    # TODO: Evaluate alternatives to 'eval' for executing complex commands
	# Using 'eval' here allows for dynamic execution of commands that may include
	# special characters, variable expansions, or other complexities that are
	# difficult to handle with direct execution methods. However, 'eval' comes with
	# significant security implications, especially when dealing with untrusted input.
	# It executes the given string as a bash command, which can lead to code injection
	# vulnerabilities if not carefully managed. This usage is a temporary solution to
	# achieve desired functionality and should be revisited to explore safer alternatives.
    if [[ "$show_output" == "show_output" ]]; then
        eval $cmd 2>> "$TMP_LOGFILE"
    else
        eval $cmd > /dev/null 2>> "$TMP_LOGFILE"
    fi

    cmd_exit_status=${PIPESTATUS[0]} # Get exit status of the first command in the last pipe

    if [[ -f "$TMP_LOGFILE" ]]; then
        log_text=$(cat "$TMP_LOGFILE")
        >> "$LOGFILE" # Clear TMP_LOGFILE after reading
    fi

    if [[ $cmd_exit_status -ne 0 ]]; then
        if [[ "$exit_behavior" != "no_exit" ]]; then
            if [[ -n "$log_text" ]]; then
                my_echo -e "\033[31;1mERROR:\033[0m $log_text"
                my_echo "ERROR: $log_text" >> "$LOGFILE"
            fi
            exit 1
        else
            if [[ -n "$log_text" ]]; then
                my_echo -e "\033[37;1mNOTE:\033[0m $log_text"
                my_echo "NOTE: $log_text" >> "$LOGFILE"
            fi
        fi
    fi
}

function get_metaname () {
	local TMP_NAME=$1

	if [ "$TMP_NAME" == "hd51" ] || [ "$TMP_NAME" == "bre2ze4k" ] || [ "$TMP_NAME" == "mutant51" ] || [ "$TMP_NAME" == "ax51" ]; then
		META_NAME="gfutures"
	elif [ "$TMP_NAME" == "h7" ] || [ "$TMP_NAME" == "zgemmah7" ]; then
		META_NAME="airdigital"
	elif [ "$TMP_NAME" == "hd60" ] || [ "$TMP_NAME" == "hd61" ] || [ "$TMP_NAME" == "ax60" ] || [ "$TMP_NAME" == "ax61" ]; then
		META_NAME="hisilicon"
	elif [ "$TMP_NAME" == "osmio4k" ] || [ "$TMP_NAME" == "osmio4kplus" ]; then
		META_NAME="edision"
    elif [ "$TMP_NAME" == "e4hdultra" ]; then
		META_NAME="ceryon"
	else
		META_NAME=$TMP_NAME
	fi
	echo "$META_NAME"
}

# clone or update required branch for required meta-<layer>
function fetch_meta() {
    local layer_name="$1"
    local branch_name="$2"
    local layer_git_url="$3"
    local branch_hash="$4"
    local target_git_path="$5"
    local patch_list="$6"

    local GIT_SSH_COMMAND=""
    if [[ "$GIT_SSH_KEYFILE" != "" ]]; then
        export GIT_SSH_COMMAND="$SSH -i \"$GIT_SSH_KEYFILE\""
    fi

    if [[ ! -d "$target_git_path/.git" ]]; then
		my_echo -e "Clone branch $branch_name from $layer_git_url into $target_git_path"
		if do_exec "git clone -b "$branch_name" "$layer_git_url" "$target_git_path""; then
			do_exec "git -C "$target_git_path" checkout "$branch_hash" -b "$IMAGE_VERSION""
			do_exec "git -C "$target_git_path" pull -r origin "$branch_name""
		else
			my_echo -e "\033[31;1mError cloning $layer_name from $layer_git_url\033[0m"
			return 1
		fi
		## Patching
		if [[ -n "$patch_list" ]]; then
			for patch_file in $patch_list; do
				# First, check if the patch can be applied cleanly
				my_echo -e "Applying patch: $patch_file"
				if do_exec "git -C "$target_git_path" apply --check "$FILES_DIR/$patch_file""; then
					# Attempt to apply the patch if 'apply --check' was successful
					if ! do_exec "git -C "$target_git_path" am < "$FILES_DIR/$patch_file""; then
						# Error message if 'git am' fails
						my_echo -e "\033[31;1mFailed to apply patch $patch_file to $layer_name\033[0m"
						return 1
					fi
				else
					# Message about skipping if 'apply --check' fails
					my_echo -e "\033[33;1mSkipping patch $patch_file already applied or cannot be applied cleanly.\033[0m"
				fi
			done
		fi
    else
		if [[ $DO_UPDATE == "$true" ]]; then
			my_echo -e "Update $target_git_path on branch $branch_name"
			if [[ $(git -C "$target_git_path" stash list) ]]; then
				my_echo -e "Stashing changes in $target_git_path"
				do_exec "git -C "$target_git_path" stash push --include-untracked"
				local stash_applied=true
			fi
			do_exec "git -C "$target_git_path" checkout "$branch_name"" || do_exec "git -C "$target_git_path" checkout -b "$branch_name""
			do_exec "git -C "$target_git_path" pull -r origin "$branch_name""
			if [[ "$stash_applied" == true ]]; then
				if do_exec "git -C "$target_git_path" stash pop"; then
					my_echo -e "Stash applied successfully."
				else
					my_echo -e "\033[33;1mNote: Stash could not be applied. Manual intervention required.\033[0m"
					return 1
				fi
			fi
        fi
    fi

    return 0
}

# clone/update required branch from tuxbox bsp layers
function is_required_machine_layer ()
{
	local HIM1=$1
	for M in $HIM1 ; do
		if [ "$M" == "$MACHINE" ]; then
			echo true
			return 1
		fi
	done
	echo false
	return 0
}

# get matching machine type from machine build id
function get_real_machine_type() {
	local MACHINE_TYPE=$1
	if  [ "$MACHINE_TYPE" == "mutant51" ] || [ "$MACHINE_TYPE" == "ax51" ] || [ "$MACHINE_TYPE" == "hd51" ]; then
		RMT_RES="hd51"
	elif  [ "$MACHINE_TYPE" == "hd60" ] || [ "$MACHINE_TYPE" == "ax60" ]; then
		RMT_RES="hd60"
	elif  [ "$MACHINE_TYPE" == "hd61" ] || [ "$MACHINE_TYPE" == "ax61" ]; then
		RMT_RES="hd61"
	elif  [ "$MACHINE_TYPE" == "zgemmah7" ] || [ "$MACHINE_TYPE" == "h7" ]; then
		RMT_RES="h7"
	else
		RMT_RES=$MACHINE_TYPE
	fi
	echo $RMT_RES
}

# get matching machine build id from machine type
function get_real_machine_id() {
	local MACHINEBUILD=$1
	if  [ "$MACHINEBUILD" == "hd51" ]; then
		RMI_RES="ax51"
	elif  [ "$MACHINEBUILD" == "hd60" ]; then
		RMI_RES="ax60"
	elif  [ "$MACHINEBUILD" == "hd61" ]; then
		RMI_RES="ax61"
	elif  [ "$MACHINEBUILD" == "h7" ]; then
		RMI_RES="zgemmah7"
	else
		RMI_RES=$MACHINEBUILD
	fi
	echo $RMI_RES
}

# function to create file entries into a file, already existing entry will be ignored
function set_file_entry () {
	local FILE_NAME=$1
	local FILE_SEARCH_ENTRY=$2
	local FILE_NEW_ENTRY=$3
	if test ! -f $FILE_NAME; then
		echo $FILE_NEW_ENTRY > $FILE_NAME
		return 1
	else
		OLD_CONTENT=`cat $FILE_NAME`
		HAS_ENTRY=`grep -c -w $FILE_SEARCH_ENTRY $FILE_NAME`
		if [ "$HAS_ENTRY" == "0" ] ; then
			echo $FILE_NEW_ENTRY >> $FILE_NAME
		fi
		NEW_CONTENT=`cat $FILE_NAME`
		if [ "$OLD_CONTENT" == "$NEW_CONTENT" ] ; then
			return 1
		fi
	fi
	return 0
}


# function to create configuration for box types
function create_local_config () {
	local machine=$1

	if [ "$machine" != "all" ]; then

		MACHINE_BUILD_DIR=$BUILD_ROOT/$machine
		do_exec "mkdir -p $BUILD_ROOT"

		BACKUP_CONFIG_DIR="$BACKUP_PATH/$machine/conf"
		do_exec "mkdir -p $BACKUP_CONFIG_DIR"

		LOCAL_CONFIG_FILE_PATH=$MACHINE_BUILD_DIR/conf/local.conf

		if test -d $BUILD_ROOT_DIR/$machine; then
			if test ! -L $BUILD_ROOT_DIR/$machine; then
				# generate build/config symlinks for compatibility
				my_echo -e "\033[37;1m\tcreate compatible symlinks directory for $machine environment ...\033[0m"
				do_exec "mv $BUILD_ROOT_DIR/$machine $BUILD_ROOT"
				do_exec "ln -s $MACHINE_BUILD_DIR $BUILD_ROOT_DIR/$machine"
			fi
		fi

		# generate default config
		if test ! -d $MACHINE_BUILD_DIR/conf; then
			my_echo -e "\033[37;1m\tcreating build directory for $machine environment ...\033[0m"
			do_exec "cd $BUILD_ROOT_DIR"
			do_exec ". ./oe-init-build-env $MACHINE_BUILD_DIR"
			# we need a clean config file
			if test -f $LOCAL_CONFIG_FILE_PATH & test ! -f $LOCAL_CONFIG_FILE_PATH.origin; then
				# so we save the origin local.conf
				do_exec "mv $LOCAL_CONFIG_FILE_PATH $LOCAL_CONFIG_FILE_PATH.origin"
			fi
			do_exec "cd $BASEPATH"
			echo "[Desktop Entry]" > $BUILD_ROOT/.directory
			echo "Icon=folder-green" >> $BUILD_ROOT/.directory
		fi

		# modify or upgrade config files inside conf directory
		if test -f $LOCAL_CONFIG_FILE_INC_PATH; then

			if test -f $LOCAL_CONFIG_FILE_PATH; then
				HASHSTAMP=`MD5SUM $LOCAL_CONFIG_FILE_PATH`
				do_exec "cp $LOCAL_CONFIG_FILE_PATH $BACKUP_CONFIG_DIR/local.conf.$HASHSTAMP.$BACKUP_SUFFIX"

				# migrate settings after server switch
				my_echo "migrate settings within $LOCAL_CONFIG_FILE_INC_PATH..."
				do_exec "sed -i -e 's|http://archiv.tuxbox-neutrino.org|https://n4k.sourceforge.io|' $LOCAL_CONFIG_FILE_INC_PATH"
				do_exec "sed -i -e 's|https://archiv.tuxbox-neutrino.org|https://n4k.sourceforge.io|' $LOCAL_CONFIG_FILE_INC_PATH"

				do_exec "sed -i -e 's|http://archiv.tuxbox-neutrino.org/sources|https://n4k.sourceforge.io/sources|' $LOCAL_CONFIG_FILE_INC_PATH"
				do_exec "sed -i -e 's|https://archiv.tuxbox-neutrino.org/sources|https://n4k.sourceforge.io/sources|' $LOCAL_CONFIG_FILE_INC_PATH"

				do_exec "sed -i -e 's|http://sstate.tuxbox-neutrino.org|https://n4k.sourceforge.io|' $LOCAL_CONFIG_FILE_INC_PATH"
				do_exec "sed -i -e 's|https://sstate.tuxbox-neutrino.org|https://n4k.sourceforge.io|' $LOCAL_CONFIG_FILE_INC_PATH"

				do_exec "sed -i -e 's|archiv.tuxbox-neutrino.org|n4k.sourceforge.io|' $LOCAL_CONFIG_FILE_INC_PATH"
				do_exec "sed -i -e 's|sstate.tuxbox-neutrino.org|n4k.sourceforge.io|' $LOCAL_CONFIG_FILE_INC_PATH"

				my_echo "migrate settings within $LOCAL_CONFIG_FILE_PATH"
				do_exec "sed -i -e 's|http://archiv.tuxbox-neutrino.org|https://n4k.sourceforge.io|' $LOCAL_CONFIG_FILE_PATH"
				do_exec "sed -i -e 's|https://archiv.tuxbox-neutrino.org|https://n4k.sourceforge.io|' $LOCAL_CONFIG_FILE_PATH"

				do_exec "sed -i -e 's|http://archiv.tuxbox-neutrino.org/sources|https://n4k.sourceforge.io/sources|' $LOCAL_CONFIG_FILE_PATH"
				do_exec "sed -i -e 's|https://archiv.tuxbox-neutrino.org/sources|https://n4k.sourceforge.io/sources|' $LOCAL_CONFIG_FILE_PATH"

				do_exec "sed -i -e 's|http://sstate.tuxbox-neutrino.org|https://n4k.sourceforge.io|' $LOCAL_CONFIG_FILE_PATH"
				do_exec "sed -i -e 's|https://sstate.tuxbox-neutrino.org|https://n4k.sourceforge.io|' $LOCAL_CONFIG_FILE_PATH"

				do_exec "sed -i -e 's|archiv.tuxbox-neutrino.org|n4k.sourceforge.io|' $LOCAL_CONFIG_FILE_PATH"
				do_exec "sed -i -e 's|sstate.tuxbox-neutrino.org|n4k.sourceforge.io|' $LOCAL_CONFIG_FILE_PATH"

				search_line="#UPDATE_SERVER_URL = \"http:\/\/@hostname@\""
				add_line="UPDATE_SERVER_URL = \"http://$HTTP_ADDRESS\""
				if ! grep -qF -- "$add_line" "$LOCAL_CONFIG_FILE_INC_PATH"; then
					# Wenn nicht, füge die neue Zeile nach der spezifischen Zeile ein
					sed -i -e "/$search_line/a $add_line" "$LOCAL_CONFIG_FILE_INC_PATH"
				fi
			fi

			# add init note
			set_file_entry $LOCAL_CONFIG_FILE_PATH "generated" "# auto generated entries by init script"

			# add line 1, include for local.conf.common.inc
			set_file_entry $LOCAL_CONFIG_FILE_PATH "$BASEPATH/local.conf.common.inc" "include $BASEPATH/local.conf.common.inc"

			# add line 2, machine type
			M_TYPE='MACHINE = "'`get_real_machine_type $machine`'"'
			if set_file_entry $LOCAL_CONFIG_FILE_PATH "MACHINE" "$M_TYPE" == 1; then
				my_echo -e "\t\033[37;1m$LOCAL_CONFIG_FILE_PATH has been upgraded with entry: $M_TYPE \033[0m"
			fi

			# add line 3, machine build
			M_ID='MACHINEBUILD = "'`get_real_machine_id $machine`'"'
			if set_file_entry $LOCAL_CONFIG_FILE_PATH "MACHINEBUILD" "$M_ID" == 1; then
				my_echo -e "\t\033[37;1m$LOCAL_CONFIG_FILE_PATH has been upgraded with entry: $M_ID \033[0m"
			fi
		else
			my_echo -e "\033[31;1mERROR:\033[0m:\ttemplate $BASEPATH/local.conf.common.inc not found..."
			exit 1
		fi

		BBLAYER_CONF_FILE="$MACHINE_BUILD_DIR/conf/bblayers.conf"

		# craete backup for bblayer.conf
		if test -f $BBLAYER_CONF_FILE; then
			HASHSTAMP=`MD5SUM $BBLAYER_CONF_FILE`
			do_exec "cp $BBLAYER_CONF_FILE $BACKUP_CONFIG_DIR/bblayer.conf.$HASHSTAMP.$BACKUP_SUFFIX"
		fi

		META_MACHINE_LAYER=meta-`get_metaname $machine`

		# add layer entries into bblayer.conf
		set_file_entry $BBLAYER_CONF_FILE "generated" '# auto generated entries by init script'
		LAYER_LIST=" $TUXBOX_LAYER_NAME $META_MACHINE_LAYER $OE_LAYER_NAME/meta-oe $OE_LAYER_NAME/meta-networking $PYTHON2_LAYER_NAME $QT5_LAYER_NAME "
		for LL in $LAYER_LIST ; do
			if set_file_entry $BBLAYER_CONF_FILE $LL 'BBLAYERS += " '$BUILD_ROOT_DIR'/'$LL' "' == 1;then
				my_echo -e "\t\033[37;1m$BBLAYER_CONF_FILE has been upgraded with entry: $LL... \033[0m"
			fi
		done
	fi
}

# function create local dist directory to prepare for web access
function create_dist_tree () {

	# create dist dir
	DIST_BASEDIR="$DIST_DIR/$IMAGE_VERSION"
	if test ! -d "$DIST_BASEDIR"; then
		my_echo -e "\033[37;1mcreate dist directory:\033[0m   $DIST_BASEDIR"
		do_exec "mkdir -p $DIST_BASEDIR"
	fi

	# create link sources
	DIST_LIST=`ls $BUILD_ROOT`
	for DL in  $DIST_LIST ; do
		DEPLOY_DIR="$BUILD_ROOT/$DL/tmp/deploy"
		do_exec "ln -sf $DEPLOY_DIR $DIST_BASEDIR/$DL"
		if test -L "$DIST_BASEDIR/$DL/deploy"; then
			do_exec "unlink $DIST_BASEDIR/$DL/deploy"
		fi
	done
}

function MD5SUM () {
	local MD5SUM_FILE=$1
	MD5STAMP=`md5sum $MD5SUM_FILE |cut -f 1 -d " "`
	echo $MD5STAMP
}

# Function for selecting for items included a custom entry
function do_select() {
    local items="$1"
    SELECTION=""
    local user_input
    local valid_selection=0

    IFS=' ' read -r -a items_array <<< "$items"

    echo "Please select one or more entries (numbers separated by spaces):"
    local i=1
    for item in "${items_array[@]}"; do
        printf "[%2d]  %s\n" "$i" "$item"
        ((i++))
    done
    printf "\n[%2d]  %s\n" "$i" "Enter custom"

    printf "\nEnter the numbers of the entries or [$i] for custom entry: "
    read -r user_input

    for choice in $user_input; do
        if [[ "$choice" =~ ^[0-9]+$ ]]; then
            if [ "$choice" -ge 1 ] && [ "$choice" -lt "$i" ]; then
                SELECTION+="${items_array[$choice-1]} "
                valid_selection=1
            elif [ "$choice" -eq "$i" ]; then
                echo "Enter your custom entry:"
                read -r custom_entry
                SELECTION+="$custom_entry "
                valid_selection=1
            else
                my_echo "Invalid selection: $choice"
            fi
        else
            my_echo "Invalid selection: $choice"
        fi
    done

    if [ "$valid_selection" -eq 0 ]; then
        my_echo "No valid selection made. Process aborted."
        return 1
    fi

    # Remove the last space
    SELECTION=$(echo "$SELECTION" | sed 's/ $//')

    my_echo "Selected entries: $SELECTION"
    # Return the selected machines as a string
    #"$SELECTION" has global scope
}


# Reset the build. Nothing is deleted, but rather renamed for safety.
# Users can then decide when they want to clean up permanently.
function do_reset() {
    # Make selection and save in a variable
    do_select "$MACHINES"
    local selected_machines=$SELECTION

    # Check if a selection was made
    if [ -z "$selected_machines" ]; then
        return
    fi

    # Set the start directory from where the search should begin
    local start_directory="$BUILD_ROOT_DIR" # Adjust to base directory
    local rename_success=0 # Tracks if a rename was performed

    # Process the selected machines
    IFS=' ' read -r -a machines_array <<< "$selected_machines"
    for machine in "${machines_array[@]}"; do
        my_echo "Reset is being carried out for: $machine"

        # Save results from find in an array
        readarray -t found_dirs < <(find "$start_directory" -type f -name "saved_tmpdir")

        # Check if the array contains elements
        for dir in "${found_dirs[@]}"; do
            # Read the path from the file
            tmp_dir_path=$(cat "$dir")
            # Check if the path exists and matches the machine name
            if [[ -d "$tmp_dir_path" && "$tmp_dir_path" == *"/$machine/tmp"* ]]; then
                local timestamp=$(date '+%Y%m%d_%H%M%S')
                do_exec "mv "$tmp_dir_path" "${tmp_dir_path%/*}/tmp_${timestamp}""
                my_echo "Folder $tmp_dir_path was renamed to ${tmp_dir_path%/*}/tmp_${timestamp}."
                rename_success=1
                break # Exit the loop after the first successful rename
            fi
        done
    done

    # Check if reset was performed
    if [ "$rename_success" -eq 0 ]; then
       my_echo "\033[33mNo reset could be performed.\033[0m"
	else
		my_echo "Reset succeeded."
    fi
}

