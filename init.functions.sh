#!/bin/bash

## Function to replace the echo command
function my_echo() {
    local no_term_output="$1"
    # Clean up text
    if [ "$no_term_output" == "true" ]; then
        shift
    fi
    local cleaned_output
    cleaned_output=$(echo -e "${@}" | sed -r "s/\x1B\[[0-9;]*[a-zA-Z]//g")
    # Write to log
    echo "[ $(date '+%Y-%m-%d %H:%M:%S') ] - ${cleaned_output}" >> "$LOGFILE"
    # Show on terminal
    if [[ "$no_term_output" != "true" && -t 1 ]]; then
        echo -e "${@}"
    fi
}

## Function to check if a machine is valid
# Returns 0 if valid, 1 if not.
function is_valid_machine() {
    local machine_to_check="$1"
    for m in $MACHINES; do
        if [[ "$machine_to_check" == "$m" || "$MACHINE" == "all" ]]; then
            return 0  # valid
        fi
    done
    return 1  # not valid
}

function do_exec() {
    local cmd="$1"
    local exit_behavior="$2"
    local show_output="$3"
    local log_text
    local cmd_exit_status

    my_echo true "[EXEC] $cmd"

    # Execute the command
    if [[ "$show_output" == "show_output" ]]; then
        eval $cmd 2>> "$TMP_LOGFILE"
    else
        eval $cmd > /dev/null 2>> "$TMP_LOGFILE"
    fi

    cmd_exit_status=${PIPESTATUS[0]} # Get exit status of the first command in the last pipe

    if [[ -f "$TMP_LOGFILE" ]]; then
        log_text=$(cat "$TMP_LOGFILE")
        : > "$TMP_LOGFILE"  # Clear TMP_LOGFILE after reading
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

function get_metaname() {
    local TMP_NAME="$1"

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
        META_NAME="$TMP_NAME"
    fi
    echo "$META_NAME"
}

## Function to apply a patch using git apply with check and commit
# Parameters:
#   $1: target_git_path (Path to the Git repository)
#   $2: patch_file (Name of the patch file located in $FILES_DIR)
#   $3: layer_name (Name of the layer, only for log output)
function apply_patch() {
    local target_git_path="$1"
    local patch_file="$2"
    local layer_name="$3"

    my_echo -e "Applying patch: $patch_file"

    # Check if the patch has already been applied by testing it in reverse
    if git -C "$target_git_path" apply --reverse --check "$FILES_DIR/$patch_file" > /dev/null 2>&1; then
        my_echo -e "\033[33;1mPatch $patch_file already applied to $layer_name; skipping.\033[0m"
        return 0
    fi

    # Check if the patch can be applied cleanly
    if do_exec "git -C \"$target_git_path\" apply --check \"$FILES_DIR/$patch_file\""; then
        if do_exec "git -C \"$target_git_path\" apply \"$FILES_DIR/$patch_file\""; then
            # After successfully applying the patch: add changes and commit
            do_exec "git -C \"$target_git_path\" add -A"
            do_exec "git -C \"$target_git_path\" commit -m \"Apply patch $patch_file\""
        else
            my_echo -e "\033[31;1mFailed to apply patch $patch_file to $layer_name using git apply\033[0m"
            return 1
        fi
    else
        my_echo -e "\033[33;1mSkipping patch $patch_file: cannot be applied cleanly.\033[0m"
    fi

    return 0
}

## Clone or update required branch for a meta-layer
function fetch_meta() {
    local layer_name="$1"
    local branch_name="$2"
    local layer_git_url="$3"
    local branch_hash="$4"
    local target_git_path="$5"
    local patch_list="$6"

    if [[ "$GIT_SSH_KEYFILE" != "" ]]; then
        export GIT_SSH_COMMAND="$SSH -i \"$GIT_SSH_KEYFILE\""
    fi

    if [[ ! -d "$target_git_path/.git" ]]; then
        my_echo -e "Clone branch $branch_name from $layer_git_url into $target_git_path"
        if do_exec "git clone -b \"$branch_name\" \"$layer_git_url\" \"$target_git_path\""; then
            # Only perform checkout if branch_hash is not empty
            if [ -n "$branch_hash" ]; then
                do_exec "git -C \"$target_git_path\" checkout \"$branch_hash\" -b \"$IMAGE_VERSION\""
            fi
            do_exec "git -C \"$target_git_path\" pull -r origin \"$branch_name\""
        else
            my_echo -e "\033[31;1mError cloning $layer_name from $layer_git_url\033[0m"
            return 1
        fi
        ## Patching
        if [[ -n "$patch_list" ]]; then
            for patch_file in $patch_list; do
                if ! apply_patch "$target_git_path" "$patch_file" "$layer_name"; then
                    return 1
                fi
            done
        fi
    else
        if [[ $DO_UPDATE == "$true" ]]; then
            my_echo -e "Update $target_git_path on branch $branch_name"
            if [[ $(git -C "$target_git_path" stash list) ]]; then
                my_echo -e "Stashing changes in $target_git_path"
                do_exec "git -C \"$target_git_path\" stash push --include-untracked"
                local stash_applied=true
            fi
            do_exec "git -C \"$target_git_path\" checkout \"$branch_name\"" || do_exec "git -C \"$target_git_path\" checkout -b \"$branch_name\""
            do_exec "git -C \"$target_git_path\" pull -r origin \"$branch_name\""
            ## Patching
            if [[ -n "$patch_list" ]]; then
                for patch_file in $patch_list; do
                    if ! apply_patch "$target_git_path" "$patch_file" "$layer_name"; then
                        return 1
                    fi
                done
            fi
            if [[ "$stash_applied" == true ]]; then
                if do_exec "git -C \"$target_git_path\" stash pop"; then
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

## Clone/update required branch from tuxbox bsp layers
# Returns 0 if machine is required, 1 if not.
function is_required_machine_layer() {
    local machine_list="$1"
    for m in $machine_list; do
        if [[ "$m" == "$MACHINE" ]]; then
            return 0  # required
        fi
    done
    return 1  # not required
}

## Get matching machine type from machine build id
function get_real_machine_type() {
    local MACHINE_TYPE="$1"
    if  [ "$MACHINE_TYPE" == "mutant51" ] || [ "$MACHINE_TYPE" == "ax51" ] || [ "$MACHINE_TYPE" == "hd51" ]; then
        echo "hd51"
    elif  [ "$MACHINE_TYPE" == "hd60" ] || [ "$MACHINE_TYPE" == "ax60" ]; then
        echo "hd60"
    elif  [ "$MACHINE_TYPE" == "hd61" ] || [ "$MACHINE_TYPE" == "ax61" ]; then
        echo "hd61"
    elif  [ "$MACHINE_TYPE" == "zgemmah7" ] || [ "$MACHINE_TYPE" == "h7" ]; then
        echo "h7"
    else
        echo "$MACHINE_TYPE"
    fi
}

## Get matching machine build id from machine type
function get_real_machine_id() {
    local MACHINEBUILD="$1"
    if  [ "$MACHINEBUILD" == "hd51" ]; then
        echo "ax51"
    elif  [ "$MACHINEBUILD" == "hd60" ]; then
        echo "ax60"
    elif  [ "$MACHINEBUILD" == "hd61" ]; then
        echo "ax61"
    elif  [ "$MACHINEBUILD" == "h7" ]; then
        echo "zgemmah7"
    else
        echo "$MACHINEBUILD"
    fi
}

## Function to add an entry to a file if it doesn't already exist.
## Returns 0 if entry was added, 1 if it already existed.
function set_file_entry() {
    local FILE_NAME="$1"
    local FILE_SEARCH_ENTRY="$2"
    local FILE_NEW_ENTRY="$3"
    if [ ! -f "$FILE_NAME" ]; then
        echo "$FILE_NEW_ENTRY" > "$FILE_NAME"
        return 0
    else
        if grep -q -w "$FILE_SEARCH_ENTRY" "$FILE_NAME"; then
            return 1  # entry exists
        else
            echo "$FILE_NEW_ENTRY" >> "$FILE_NAME"
            return 0
        fi
    fi
}

## Function to create configuration for box types
function create_local_config() {
    local machine="$1"

    if [ "$machine" != "all" ]; then
        MACHINE_BUILD_DIR="$BUILD_ROOT/$machine"
        do_exec "mkdir -p \"$BUILD_ROOT\""

        BACKUP_CONFIG_DIR="$BACKUP_PATH/$machine/conf"
        do_exec "mkdir -p \"$BACKUP_CONFIG_DIR\""

        LOCAL_CONFIG_FILE_PATH="$MACHINE_BUILD_DIR/conf/local.conf"

        if [ -d "$BUILD_ROOT_DIR/$machine" ]; then
            if [ ! -L "$BUILD_ROOT_DIR/$machine" ]; then
                my_echo -e "\033[37;1m\tcreate compatible symlinks directory for $machine environment ...\033[0m"
                do_exec "mv \"$BUILD_ROOT_DIR/$machine\" \"$BUILD_ROOT\""
                do_exec "ln -s \"$MACHINE_BUILD_DIR\" \"$BUILD_ROOT_DIR/$machine\""
            fi
        fi

        if [ ! -d "$MACHINE_BUILD_DIR/conf" ]; then
            my_echo -e "\033[37;1m\tcreating build directory for $machine environment ...\033[0m"
            do_exec "cd \"$BUILD_ROOT_DIR\""
            do_exec ". ./oe-init-build-env \"$MACHINE_BUILD_DIR\""
            if [ -f "$LOCAL_CONFIG_FILE_PATH" ] && [ ! -f "$LOCAL_CONFIG_FILE_PATH.origin" ]; then
                do_exec "mv \"$LOCAL_CONFIG_FILE_PATH\" \"$LOCAL_CONFIG_FILE_PATH.origin\""
            fi
            do_exec "cd \"$BASEPATH\""
            echo "[Desktop Entry]" > "$BUILD_ROOT/.directory"
            echo "Icon=folder-green" >> "$BUILD_ROOT/.directory"
        fi

        if [ -f "$LOCAL_CONFIG_FILE_INC_PATH" ]; then
            if [ -f "$LOCAL_CONFIG_FILE_PATH" ]; then
                HASHSTAMP=$(MD5SUM "$LOCAL_CONFIG_FILE_PATH")
                do_exec "cp \"$LOCAL_CONFIG_FILE_PATH\" \"$BACKUP_CONFIG_DIR/local.conf.$HASHSTAMP.$BACKUP_SUFFIX\""
                my_echo "migrate settings within $LOCAL_CONFIG_FILE_INC_PATH..."
                do_exec "sed -i -e 's|http://archiv.tuxbox-neutrino.org|https://n4k.sourceforge.io|g' \"$LOCAL_CONFIG_FILE_INC_PATH\""
                do_exec "sed -i -e 's|https://archiv.tuxbox-neutrino.org|https://n4k.sourceforge.io|g' \"$LOCAL_CONFIG_FILE_INC_PATH\""
                do_exec "sed -i -e 's|http://archiv.tuxbox-neutrino.org/sources|https://n4k.sourceforge.io/sources|g' \"$LOCAL_CONFIG_FILE_INC_PATH\""
                do_exec "sed -i -e 's|https://archiv.tuxbox-neutrino.org/sources|https://n4k.sourceforge.io/sources|g' \"$LOCAL_CONFIG_FILE_INC_PATH\""
                do_exec "sed -i -e 's|http://sstate.tuxbox-neutrino.org|https://n4k.sourceforge.io|g' \"$LOCAL_CONFIG_FILE_INC_PATH\""
                do_exec "sed -i -e 's|https://sstate.tuxbox-neutrino.org|https://n4k.sourceforge.io|g' \"$LOCAL_CONFIG_FILE_INC_PATH\""
                do_exec "sed -i -e 's|archiv.tuxbox-neutrino.org|n4k.sourceforge.io|g' \"$LOCAL_CONFIG_FILE_INC_PATH\""
                do_exec "sed -i -e 's|sstate.tuxbox-neutrino.org|n4k.sourceforge.io|g' \"$LOCAL_CONFIG_FILE_INC_PATH\""

                my_echo "migrate settings within $LOCAL_CONFIG_FILE_PATH"
                do_exec "sed -i -e 's|http://archiv.tuxbox-neutrino.org|https://n4k.sourceforge.io|g' \"$LOCAL_CONFIG_FILE_PATH\""
                do_exec "sed -i -e 's|https://archiv.tuxbox-neutrino.org|https://n4k.sourceforge.io|g' \"$LOCAL_CONFIG_FILE_PATH\""
                do_exec "sed -i -e 's|http://archiv.tuxbox-neutrino.org/sources|https://n4k.sourceforge.io/sources|g' \"$LOCAL_CONFIG_FILE_PATH\""
                do_exec "sed -i -e 's|https://archiv.tuxbox-neutrino.org/sources|https://n4k.sourceforge.io/sources|g' \"$LOCAL_CONFIG_FILE_PATH\""
                do_exec "sed -i -e 's|http://sstate.tuxbox-neutrino.org|https://n4k.sourceforge.io|g' \"$LOCAL_CONFIG_FILE_PATH\""
                do_exec "sed -i -e 's|https://sstate.tuxbox-neutrino.org|https://n4k.sourceforge.io|g' \"$LOCAL_CONFIG_FILE_PATH\""
                do_exec "sed -i -e 's|archiv.tuxbox-neutrino.org|n4k.sourceforge.io|g' \"$LOCAL_CONFIG_FILE_PATH\""
                do_exec "sed -i -e 's|sstate.tuxbox-neutrino.org|n4k.sourceforge.io|g' \"$LOCAL_CONFIG_FILE_PATH\""

                search_line="#UPDATE_SERVER_URL = \"http:\/\/@hostname@\""
                add_line="UPDATE_SERVER_URL = \"http://$HTTP_ADDRESS\""
                if ! grep -qF -- "$add_line" "$LOCAL_CONFIG_FILE_INC_PATH"; then
                    sed -i -e "/$search_line/a $add_line" "$LOCAL_CONFIG_FILE_INC_PATH"
                fi
            fi

            set_file_entry "$LOCAL_CONFIG_FILE_PATH" "generated" "# auto generated entries by init script"

            set_file_entry "$LOCAL_CONFIG_FILE_PATH" "$BASEPATH/local.conf.common.inc" "include $BASEPATH/local.conf.common.inc"

            M_TYPE='MACHINE = "'$(get_real_machine_type "$machine")'"'
            if set_file_entry "$LOCAL_CONFIG_FILE_PATH" "MACHINE" "$M_TYPE"; then
                my_echo -e "\t\033[37;1m$LOCAL_CONFIG_FILE_PATH has been upgraded with entry: $M_TYPE \033[0m"
            fi

            M_ID='MACHINEBUILD = "'$(get_real_machine_id "$machine")'"'
            if set_file_entry "$LOCAL_CONFIG_FILE_PATH" "MACHINEBUILD" "$M_ID"; then
                my_echo -e "\t\033[37;1m$LOCAL_CONFIG_FILE_PATH has been upgraded with entry: $M_ID \033[0m"
            fi
        else
            my_echo -e "\033[31;1mERROR:\033[0m:\ttemplate $BASEPATH/local.conf.common.inc not found..."
            exit 1
        fi

        BBLAYER_CONF_FILE="$MACHINE_BUILD_DIR/conf/bblayers.conf"

        if [ -f "$BBLAYER_CONF_FILE" ]; then
            HASHSTAMP=$(MD5SUM "$BBLAYER_CONF_FILE")
            do_exec "cp \"$BBLAYER_CONF_FILE\" \"$BACKUP_CONFIG_DIR/bblayer.conf.$HASHSTAMP.$BACKUP_SUFFIX\""
        fi

        META_MACHINE_LAYER="meta-$(get_metaname "$machine")"

        set_file_entry "$BBLAYER_CONF_FILE" "generated" "# auto generated entries by init script"

        if [[ -z "$PYTHON2_SRCREV" ]]; then
            PYTHON2_LAYER_NAME=""
        fi

        LAYER_LIST="$TUXBOX_LAYER_NAME $META_MACHINE_LAYER $OE_LAYER_NAME/meta-oe $OE_LAYER_NAME/meta-networking $PYTHON2_LAYER_NAME $QT5_LAYER_NAME"
        for LL in $LAYER_LIST; do
            if set_file_entry "$BBLAYER_CONF_FILE" "$LL" "BBLAYERS += \"${BUILD_ROOT_DIR}/${LL}\""; then
                my_echo -e "\t\033[37;1m$BBLAYER_CONF_FILE has been upgraded with entry: $LL... \033[0m"
            fi
        done
    fi
}

## Function to create local dist directory to prepare for web access
function create_dist_tree() {
    DIST_BASEDIR="$DIST_DIR/$IMAGE_VERSION"
    if [ ! -d "$DIST_BASEDIR" ]; then
        my_echo -e "\033[37;1mcreate dist directory:\033[0m   $DIST_BASEDIR"
        do_exec "mkdir -p \"$DIST_BASEDIR\""
    fi

    DIST_LIST=$(ls "$BUILD_ROOT")
    for DL in $DIST_LIST; do
        DEPLOY_DIR="$BUILD_ROOT/$DL/tmp/deploy"
        do_exec "ln -sf \"$DEPLOY_DIR\" \"$DIST_BASEDIR/$DL\""
        if [ -L "$DIST_BASEDIR/$DL/deploy" ]; then
            do_exec "unlink \"$DIST_BASEDIR/$DL/deploy\""
        fi
    done
}

function MD5SUM() {
    local MD5SUM_FILE="$1"
    md5sum "$MD5SUM_FILE" | cut -f 1 -d " "
}

## Function for selecting items with a custom entry
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

    SELECTION=$(echo "$SELECTION" | sed 's/ $//')
    my_echo "Selected entries: $SELECTION"
}

## Reset the build. Folders are renamed for safety.
function do_reset() {
    do_select "$MACHINES"
    local selected_machines="$SELECTION"

    if [ -z "$selected_machines" ]; then
        return
    fi

    local start_directory="$BUILD_ROOT_DIR"
    local rename_success=0

    IFS=' ' read -r -a machines_array <<< "$selected_machines"
    for machine in "${machines_array[@]}"; do
        my_echo "Reset is being carried out for: $machine"
        readarray -t found_dirs < <(find "$start_directory" -type f -name "saved_tmpdir")
        for dir in "${found_dirs[@]}"; do
            tmp_dir_path=$(cat "$dir")
            if [[ -d "$tmp_dir_path" && "$tmp_dir_path" == *"/$machine/tmp"* ]]; then
                local timestamp
                timestamp=$(date '+%Y%m%d_%H%M%S')
                do_exec "mv \"$tmp_dir_path\" \"${tmp_dir_path%/*}/tmp_${timestamp}\""
                my_echo "Folder $tmp_dir_path was renamed to ${tmp_dir_path%/*}/tmp_${timestamp}."
                rename_success=1
                break
            fi
        done
    done

    if [ "$rename_success" -eq 0 ]; then
       my_echo "\033[33mNo reset could be performed.\033[0m"
    else
       my_echo "Reset succeeded."
    fi
}
