#!/bin/zsh

#  BridgeDevSetupScript.sh
#  BridgeDeveloperToolkit
#
#  Created by Erin Mounts on 1/26/23.
#

SCRIPT_NAME="$0"

print Running $SCRIPT_NAME $@ ...

if [[ -t 0 ]]; then
    print "Running in a terminal"
    curl_progress=""
else
    print "Not running in a terminal--no user input available"
    curl_progress="--no-progress-meter"
fi

##################################################################################################
#
# Install/update Xcode and set up cli tools
#
##################################################################################################

install_xcode() {
    # If we're not in an interactive shell, we can't ask questions or wait for input, so we
    # kind of have to assume this has all been taken care of manually beforehand. Most likely,
    # it means we're running as a Run Script Build Phase in Xcode anyway.

    if [[ -t 0 ]]; then
        print '============================='
        print '= Installing/updating Xcode ='
        print '============================='
        print "\n"

        xcodeurl='macappstore://apps.apple.com/us/app/xcode/id497799835?mt=12'
        xcodeInstall=`mdfind -name 'Xcode.app' 2>/dev/null`
        xcodeUpdated=false
        if [[ $xcodeInstall  =~ Xcode[.]app$ ]]; then
            read -q 'updateXcode?Do you want to update or check for updates to Xcode? (Y/N): '
            if [[ $updateXcode == y ]]; then
                open $xcodeurl
                print "\n"
                read -q 'anyKey?When you are done checking and/or updating Xcode, hit any key to continue: '
                xcodeUpdated=true
            fi
        else
            open $xcodeurl
            read -q 'anyKey?Please install Xcode from the App Store. When installation has finished, hit any key to continue: '
            xcodeUpdated=true
        fi

        print "\n"

        if $xcodeUpdated; then
            # launch Xcode to trigger request to install/update additional tools
            open -a Xcode
            print "\n"
            read -q 'anyKey?Please install Xcode additional tools. When installation has finished, hit any key to continue: '
        fi
    else
        print 'If you need to install or update the iOS development environment, please open\
        a new Terminal window, copy and paste in the following line, then hit return or enter:'
        print "cd `pwd`; sudo zsh $SCRIPT_NAME $@\n"
    fi
    sudo xcode-select -switch /Applications/Xcode.app/Contents/Developer
}

##################################################################################################
#
# Install/update iOS dev environment
#
##################################################################################################

install_ios_dev_tools() {
    print '==========================================='
    print '= Installing/updating iOS dev environment ='
    print '==========================================='
    print "\n"

    fork_from_sage "OpenBridgeApp-iOS"
    fork_from_sage "mobile-client-json"
}
uninstall_ios_dev_tools() {
    #TODO: emm 2023-02-01
}

##################################################################################################
#
# Install Bridge Server dev environment
#
##################################################################################################

install_bridge_dev_tools() {
    print "\n"
    print '====================================================='
    print '= Installing/updating Bridge Server dev environment ='
    print '====================================================='
    print "\n"

    machine=`uname -m`
    print "Machine type: $machine"
    if [[ $machine =~ ^x86_64 ]]; then
        print "Detected Intel Mac"
        corretto8url='https://corretto.aws/downloads/latest/amazon-corretto-8-x64-macos-jdk.pkg'
        jetbrainsurl='https://download.jetbrains.com/product?code=IIC&latest&distribution=mac'
        mysqlworkbenchurl='https://dev.mysql.com/get/Downloads/MySQLGUITools/mysql-workbench-community-8.0.33-macos-x86_64.dmg'
    else
        if [[ $machine =~ ^arm ]]; then
            print "Detected Apple Silicon Mac"
            corretto8url='https://corretto.aws/downloads/latest/amazon-corretto-8-aarch64-macos-jdk.pkg'
            jetbrainsurl='https://download.jetbrains.com/product?code=IIC&latest&distribution=macM1'
            mysqlworkbenchurl='https://dev.mysql.com/get/Downloads/MySQLGUITools/mysql-workbench-community-8.0.33-macos-arm64.dmg'
        else
            print "Unsupported machine type $machine"
            exit 1
        fi
    fi

    fork_from_sage "BridgeServer2"
    install_corretto
    install_intellij
    install_maven
    install_redis
    install_mysql
}

uninstall_bridge_dev_tools() {
    uninstall_mysql
    uninstall_redis
    uninstall_maven
    uninstall_intellij
    uninstall_corretto
}

# helper function to download and install an app from a .pkg
download_and_install_app_from_pkg() {
    # If we're not in an interactive shell, we can't ask questions or wait for input, so we
    # kind of have to assume this has all been taken care of manually beforehand. Most likely,
    # it means we're running as a Run Script Build Phase in Xcode anyway.

    if [[ -t 0 ]]; then
        args=()
        appname=$1
        downloadurl=$2
        pkgname=$3
        
        pushd ~/Downloads
    
        print "\n"
        print "Downloading $appname installer .pkg to `pwd`..."
        curl -L $curl_progress "$downloadurl" -o "$pkgname"
        
        open "$pkgname"
        print "\n"
        read -q "anyKey?When the installer package finishes installing $appname, hit any key to continue: "

        print "\nDeleting .pkg..."
        rm -f "$pkgname"
        
        popd
    fi
}

# install/update Corretto 8
install_corretto() {
    corretto8pkg="corretto.pkg"
    sudo download_and_install_app_from_pkg "Corretto 8" "$corretto8url" "$corretto8pkg"
    
    # Set $JAVA_HOME and $JAVA_VERSION to corretto in ~/.zshenv
    jhomercfile=~/.zshenv
    print "Setting JAVA_HOME and JAVA_VERSION in \"$jhomercfile\"..."
    corretto_home=`sudo /usr/libexec/java_home -V 2>/dev/null | egrep -o '/.*corretto.*$'`
    java_version=`sudo /usr/libexec/java_home -V 2>&1 1>/dev/null | sed -En 's/^[[:space:]]+([^[:space:]]*).*$/\1/p'`
    timestamp=$(date -j -f "%a %b %d %T %Z %Y" "`date`" "+%s")
    if [[ -e "$jhomercfile" ]]; then
        # make a backup copy of the rc file appending a timestamp extension
        cp "$jhomercfile" "$jhomercfile.$timestamp"
    fi
    print "Coretto home: $corretto_home"
    print "Java version: $java_version"
    print "RC file to be created/updated: $jhomercfile"
    export_var_as_value_from_config_file "JAVA_HOME" "$corretto_home" "$jhomercfile"
    export_var_as_value_from_config_file "JAVA_VERSION" "$java_version" "$jhomercfile"
    
    # now load it into the current environment
    source "$jhomercfile"
    print "Corretto 8 is now the active Java version."
}

uninstall_corretto() {
    #TODO: emm 2023-02-01
}

# helper function to download and install an app from a .dmg
download_and_install_app_from_dmg() {
    args=()
    appname=$1
    downloadurl=$2
    dmgname=$3
    
    pushd ~/Downloads
    
    print "\n"
    print "Downloading $appname .dmg to `pwd`..."
    curl -L $curl_progress "$downloadurl" -o "$dmgname"

    # based loosely on https://stackoverflow.com/a/55869632
    print "Mounting .dmg..."
    volume=$(hdiutil attach -nobrowse "$dmgname" | tail -n1 | cut -f3-; exit ${PIPESTATUS[0]})
    print "Copying $appname app to /Applications folder..."
    rsync -a "$volume"/*.app "/Applications/"; synced=$?
    if [[ $synced -eq 0 ]]; then
        print "$appname app successfully installed in /Applications folder"
    else
        print "Failed to install $appname app in /Applications folder, rsync exit code $synced"
    fi
    print "Unmounting .dmg..."
    hdiutil detach -force -quiet "$volume"; detached=$?
    if [[ $detached -eq 0 ]]; then
        print "Successfully unmounted $appname install disk image"
    else
        print "Failed to unmount $appname install disk image--please do it manually in Disk Utility"
    fi
    print "Deleting .dmg..."
    rm -f "$dmgname"
    
    popd

}

# install/update IntelliJ
install_intellij() {
    jetbrainsdmg="jetbrains.dmg"
    download_and_install_app_from_dmg "IntelliJ Community Edition" "$jetbrainsurl" "$jetbrainsdmg"
}

uninstall_intellij() {
    #TODO: emm 2023-02-01
}

# install/update MacPorts

install_macports() {
    port version; error=$?
    if [[ ${error} == 0 ]]; then
        # Already installed, so just update MacPorts and any outdated ports
        port selfupdate
        port upgrade outdated
    else
        macportspkgurl="https://github.com/macports/macports-base/releases/download/v2.8.1/MacPorts-2.8.1-13-Ventura.pkg"
        macportspkg="MacPorts.pkg"
        download_and_install_app_from_pkg "MacPorts" "$macportspkgurl" "$macportspkg"
    fi
}

uninstall_macports() {
    #TODO: emm 2023-03-10
}

# install (a) MacPort(s)
port_install() {
    args=()
    while (( $# )); do
        print "Installing $1 via MacPorts (password may be required)..."
        sudo port install $1
        shift
    done
}

# install/update GitHub CLI
install_githubcli() {
    port_install gh
    
    # If we're not in an interactive shell, we can't ask questions or wait for input, so we
    # kind of have to assume this has all been taken care of manually beforehand. Most likely,
    # it means we're running as a Run Script Build Phase in Xcode anyway.

    if [[ -t 0 ]]; then
        gh auth login
    fi
}

uninstall_githubcli() {
    #TODO emm 2023-04-11
}

# install/update Maven

install_maven() {
    port_install maven3
}

uninstall_maven() {
    #TODO: emm 2023-03-10
}

# install/update Redis

install_redis() {
    port_install redis
}

uninstall_redis() {
    #TODO: emm 2023-03-10
}

# helper function to download and install from a .pkg on a .dmg (why MySQL.com, why would you do this)
download_and_install_app_from_pkg_on_dmg() {
    # If we're not in an interactive shell, we can't ask questions or wait for input, so we
    # kind of have to assume this has all been taken care of manually beforehand. Most likely,
    # it means we're running as a Run Script Build Phase in Xcode anyway.

    if [[ -t 0 ]]; then
        args=()
        appname=$1
        downloadurl=$2
        dmgname=$3
        
        pushd ~/Downloads
    
        print "\n"
        print "Downloading $appname .dmg to `pwd`..."
        curl -L $curl_progress "$downloadurl" -o "$dmgname"

        # based loosely on https://stackoverflow.com/a/55869632
        print "Mounting .dmg..."
        volume=$(hdiutil attach -nobrowse "$dmgname" | tail -n1 | cut -f3-)
        print "Opening installer .pkg..."
        open "$volume"/*.pkg
        print "\n"
        read -q "anyKey?When the installer package finishes installing $appname, hit any key to continue: "


        print "\nUnmounting .dmg..."
        hdiutil detach -force -quiet "$volume"; detached=$?
        if [[ $detached -eq 0 ]]; then
            print "Successfully unmounted $appname install disk image"
        else
            print "Failed to unmount $appname install disk image--please do it manually in Disk Utility"
        fi
        print "Deleting .dmg..."
        rm -f "$dmgname"
        
        popd
    fi
}

# install/update MySQL
install_mysql() {
    mysqlurl="https://downloads.mysql.com/archives/get/p/23/file/mysql-5.7.31-macos10.14-x86_64.dmg"
    mysqldmg="mysql-5.7.31-macos10.14-x86_64.dmg"
    download_and_install_app_from_pkg_on_dmg "MySQL 5.7.31" "$mysqlurl" "$mysqldmg"
    
    pushd ~
    
    configfile=".my.cnf"
    if [[ ! -e "${configfile}" ]]; then
        # create the config file and populate it
        echo "# $configfile file created by script $SCRIPT_NAME" > "$configfile"
        echo "[mysqld]" >> "$configfile"
        echo "bind-address = 127.0.0.1" >> "$configfile"
        echo "sql-mode =" >> "${configfile}"
    fi
    
    popd

    mysqlworkbenchdmg="mysqlworkbench.dmg"
    download_and_install_app_from_dmg "MySQL Workbench 8.0.33" "$mysqlworkbenchurl" "$mysqlworkbenchdmg"
}

uninstall_mysql() {
    #TODO: emm 2023-05-12
}

# do initial setup

# set up Synapse OAuth

# update /etc/hosts

# run redis

# run Bridge

# test Bridge

# stop Bridge

# stop redis

##################################################################################################
#
# Install Android dev environment
#
##################################################################################################

install_android_dev_tools() {
    print "\n"
    print '==============================================='
    print '= Installing/updating Android dev environment ='
    print '==============================================='
    print "\n"
    
    machine=`uname -m`
    print "Machine type: $machine"
    if [[ $machine =~ ^x86_64 ]]; then
        print "Detected Intel Mac"
        androidstudiourl="https://redirector.gvt1.com/edgedl/android/studio/install/2022.2.1.20/android-studio-2022.2.1.20-mac.dmg"
    else
        if [[ $machine =~ ^arm ]]; then
            print "Detected Apple Silicon Mac"
            androidstudiourl="https://redirector.gvt1.com/edgedl/android/studio/install/2022.2.1.20/android-studio-2022.2.1.20-mac_arm.dmg"
        else
            print "Unsupported machine type $machine"
            exit 1
        fi
    fi

    androidstudiodmg="androidstudio.dmg"
    download_and_install_app_from_dmg "Android Studio Flamingo" "$androidstudiourl" "$androidstudiodmg"
    fork_from_sage "MobileToolboxApp-Android"
}

uninstall_android_dev_tools() {
    #TODO: emm 2023-02-01
}

##################################################################################################
#
# Install Web dev environment
#
##################################################################################################

install_web_dev_tools() {
    print "\n"
    print '==========================================='
    print '= Installing/updating Web dev environment ='
    print '==========================================='
    print "\n"
    
    # Per Alina:
    # - fork https://github.com/Sage-Bionetworks/mtb
    # - download your fork and set up upstream/origin as you would any other project with origin to your fork and upstream to Sage-Bionetworks
    fork_from_sage "mtb"
    
    # - download and install VS Code: https://code.visualstudio.com/
    install_vscode
    
    # - open the project directory from vscode
    # - yarn install  to install the dependencies
    # - yarn start to start the app.
    # -- (emm 2023-04-26 even in VSCode terminal, can't find yarn so we need to install it)
    port_install yarn
    pushd "$REPOHOME/mtb"

    # - One detail is that the app will start on localhost.
    # - You would need to have it in your browser to ip address http://127.0.0.1:3000/ --
    # - otherwise authentication will not work.
    # - To get started locally on 127.0.0.1: create .env.local file with HOST=127.0.0.1 inside of it.
    envFile=".env.local"
    if [[ ! -e "${envFile}" ]]; then
        # create the env file and add the host
        print "HOST=127.0.0.1\n" > "${envFile}"
    fi
    # -- (emm 2023-04-26 can't find a way to get this to happen in VSCode via this script)
    yarn install
    
    # TODO: emm 2023-04-27 installation and launch of services should be separated, with specific command line options
    # - MTB starts on :3000 and arc on :3001
    # - yarn start starts MTB
    # - yarn start:arc start ARC
    yarn start
    popd
    
}

fork_from_sage() {
    # short circuit if CLONEREPOS flag is "no"
    if [[ $CLONEREPOS == "no" ]]; then
        return
    fi
    args=()
    repo=$1
    # check if the repo already exists; if not, clone and then fork it
    if [[ ! -e "$REPOHOME/$1" ]]; then
        pushd $REPOHOME
        /opt/local/bin/gh repo clone Sage-Bionetworks/"$1"
        pushd "$1"
        /opt/local/bin/gh repo fork --remote=true
        popd
        popd
    fi
}

install_vscode() {
    print "\n"
    print "Downloading latest Visual Studio Code stable universal Darwin app .zip..."
    vscodeurl='https://code.visualstudio.com/sha/download?build=stable&os=darwin-universal'
    vscodezipfile='VSCode-darwin-universal.zip'
    vscodeapp='Visual Studio Code.app'
    pushd ~/Downloads
    
    print "Downloading into `pwd` directory"
    curl -L $curl_progress "$vscodeurl" -o "$vscodezipfile"
    print "Unzipping Visual Studio Code..."
    unzip "$vscodezipfile"
    print "Syncing Visual Studio Code app to /Applications folder..."
    rsync -a "$vscodeapp" "/Applications/"; synced=$?
    if [[ $synced -eq 0 ]]; then
        print "Visual Studio Code app successfully installed/updated in /Applications folder"
    else
        print "Failed to install/update Visual Studio Code app in /Applications folder, rsync exit code $synced"
    fi
    print "Deleting original unzipped Visual Studio Code app..."
    rm -rf "$vscodeapp"
    print "Deleting .zip file..."
    rm -f "$vscodezipfile"
    popd
}

uninstall_vscode() {
    #TODO: emm 2023-03-15
}

uninstall_web_dev_tools() {
    #TODO: emm 2023-02-01
}

##################################################################################################
#
# Main body
#
##################################################################################################

# If install_flags array is empty, we want to install everything
install_all() {
    return $#install_flags # unix shell: 0 is success, nonzero is failure
}

# Check if install_flags array contains a value (arg 1)
has_install_flag() {
    args=()
    if [[ ${install_flags[(r)$1]} == $1 ]]; then
        true
    else
        false
    fi
}

# Check if a var is already being exported by a config file. If so, update it with the given value. If not, append it.
# If the config file doesn't yet exist, create it with the specified export.
# Adapted from code written for me by ChatGPT. ~emm 2023-05-11
export_var_as_value_from_config_file() {
    args=()
    
    # Set the name of the variable you're looking for
    VAR_NAME=$1
    shift

    # Set the desired value of the variable
    VAR_VALUE=$1
    shift

    # Get the path to the config file
    CONFIG_FILE=$1

    print "Setting $VAR_NAME to \"$VAR_VALUE\" in $CONFIG_FILE"
    # Check if the config file exists
    if [ ! -f "$CONFIG_FILE" ]; then
        # If it doesn't exist, create it and add a line to export the variable
        echo "# $CONFIG_FILE file created by script $SCRIPT_NAME" > "$CONFIG_FILE"
        echo "export $VAR_NAME=\"$VAR_VALUE\"" >> "$CONFIG_FILE"
    else
        # If it exists, check if the variable is already exported
        if grep -q "export $VAR_NAME=" "$CONFIG_FILE"; then
            # If it is, replace the existing value with the new value
            pattern="export $VAR_NAME=.*"
            # First we need to escape the delimiter character in the replacement string:
            replacement="export $VAR_NAME=\\\"$VAR_VALUE\\\""
            escaped_replacement=$(printf '%s\n' "$replacement" | sed -e 's/[\/&]/\\&/g')
            printf "escaped_replacement: >>%s<<" $escaped_replacement
            sed_command="sed -i '' \"s/$pattern/$escaped_replacement/\" \"$CONFIG_FILE\""
            print "calling this sed command:"
            printf '%s\n' $sed_command
            eval ${sed_command}
        else
            # If it isn't, add a new line to export the variable with the desired value
            echo "export $VAR_NAME=\"$VAR_VALUE\"" >> "$CONFIG_FILE"
        fi
    fi
}

#if [[ `whoami` != root ]]; then
#    print "Please run this script as root or with sudo (e.g. by copying the following\n"
#    print "line, pasting it into a Terminal window, and hitting return or enter):\n"
#    print "cd `pwd`; sudo zsh $SCRIPT_NAME $@"
#    exit 1
#fi

# default location to clone GitHub repos (can override in command line with argument to -r/--repohome option)
REPOHOME="$HOME"

# default to cloning repos
CLONEREPOS="yes"

# parse command line options
zparseopts -D -E -F -a install_flags - r:=repohome -repohome:=repohome n -noclonerepos x -xcode m -macports g -gh i -iOS a -android\
        b -bridge w -web || exit 1
        
# If -r or --repohome was given, figure out where that is (or should be)
if [[ ${#repohome[@]} == 2 ]]; then
    expanded_home=$(realpath "$repohome[2]" 2>/dev/null); exists=$? # thanks, ChatGPT
    if [[ ${exists} != 0 ]]; then # nonzero result code in zsh means the function returned with an error
        # Could not get the realpath, presumably because the full path doesn't exist yet. Let's assume (for now) that
        # the specified path was a well-formed absolute or relative path, though, without any ~, ., or .. elements.
        expanded_home="$repohome[2]"
    fi
    if [[ ${expanded_home} == /* ]]; then
        # it's an absolute path
        REPOHOME="${expanded_home}"
    else
        # it's a relative path--assume it's meant to be relative to `pwd`, the directory the script was called from.
        REPOHOME="`pwd`/${expanded_home}"
    fi
fi

echo "Forked repositories will be cloned to $REPOHOME"

# make sure REPOHOME directory exists
if [[ ! -e "$REPOHOME" ]]; then
    mkdir -p $REPOHOME; exists=$?
    if [[ ${exists} != 0 ]]; then # nonzero result code in zsh means the function returned with an error
        print "Failed to create directory \"$REPOHOME\"--unable to proceed"
        exit 1
    fi
fi

# remove first -- or -
end_opts=$@[(i)(--|-)]
set -- "${@[0,end_opts-1]}" "${@[end_opts+1,-1]}"

# set up path to prioritize MacPorts binaries for the duration of the script
macPortsBin=/opt/local/bin
PATH="${macPortsBin}:${PATH}"

# Should repos not be cloned?
if has_install_flag '-n' || has_install_flag '--noclonerepos'; then
    CLONEREPOS="no"
fi

# Install Xcode
if install_all || has_install_flag '-x' || has_install_flag '--xcode'; then
    install_xcode
fi
    
# Install MacPorts
if install_all || has_install_flag '-m' || has_install_flag '--macports'; then
    install_macports
fi
    
# Install GitHub command line interface
if install_all || has_install_flag '-g' || has_install_flag '--gh'; then
    install_githubcli
fi
    
# Install iOS dev tools/environment
if install_all || has_install_flag '-i' || has_install_flag '--iOS'; then
    install_ios_dev_tools
fi

# Install Bridge dev tools/environment
if install_all || has_install_flag '-b' || has_install_flag '--bridge'; then
    install_bridge_dev_tools
fi
    
# Install Android dev tools/environment
if install_all || has_install_flag '-a' || has_install_flag '--android'; then
    install_android_dev_tools
fi
    
# Install Web dev tools/environment
if install_all || has_install_flag '-w' || has_install_flag '--web'; then
    install_web_dev_tools
fi
    

print Done running $SCRIPT_NAME $@
