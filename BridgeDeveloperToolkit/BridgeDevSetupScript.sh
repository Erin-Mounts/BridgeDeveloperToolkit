#!/bin/zsh

#  BridgeDevSetupScript.sh
#  BridgeDeveloperToolkit
#
#  Created by Erin Mounts on 1/26/23.
#

print Running $0...

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

        if $xcodeUpdated; then
            # launch Xcode to trigger request to install/update additional tools
            open -a Xcode
            print "\n"
            read -q 'anyKey?Please install Xcode additional tools. When installation has finished, hit any key to continue: '
        fi
    else
        print 'If you need to install or update the iOS development environment, please open\
        a new Terminal window, copy and paste in the following line, then hit return or enter:'
        print "cd `pwd`; sudo zsh $0"
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

    #TODO: emm 2023-04-11: fork/clone core repos for developing Sage ios apps
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
    else
        if [[ $machine =~ ^arm ]]; then
            print "Detected Apple Silicon Mac"
            corretto8url='https://corretto.aws/downloads/latest/amazon-corretto-8-aarch64-macos-jdk.pkg'
            jetbrainsurl='https://download.jetbrains.com/product?code=IIC&latest&distribution=macM1'
        else
            print "Unsupported machine type $machine"
            exit 1
        fi
    fi

    install_corretto
    install_intellij
    install_maven
    install_redis
}

uninstall_bridge_dev_tools() {
    uninstall_redis
    uninstall_maven
    uninstall_intellij
    uninstall_corretto
}

# install/update Corretto 8
install_corretto() {
    pushd ~/Downloads
    
    print "\n"
    print "Downloading latest Corretto 8 .pkg to `pwd`..."
    corretto8pkg="corretto.pkg"
    curl -L $curl_progress "$corretto8url" -o "$corretto8pkg"

    open "$corretto8pkg"
    read -q 'anyKey?Please follow the installer prompts to install Corretto 8. When installation has finished, hit any key to continue: '

    print "Deleting .pkg..."
    rm -f "$corretto8pkg"

    popd
    
    # Set $JAVA_HOME and $JAVA_VERSION to corretto in ~/.zshenv
    jhomercfile=~/.zshenv
    print "Setting JAVA_HOME and JAVA_VERSION in \"$jhomercfile\"..."
    corretto_home=`/usr/libexec/java_home -V 2>/dev/null | egrep -o '/.*corretto.*$'`
    java_home_export="export JAVA_HOME=\"$corretto_home\""
    java_version_export=`/usr/libexec/java_home -V 2>&1 1>/dev/null | sed -En 's/^[[:space:]]+([^[:space:]]*).*$/\1/p'`
    timestamp=$(date -j -f "%a %b %d %T %Z %Y" "`date`" "+%s")
    #TODO: emm 2023-02-27 check if the exports already exist and if so, overwrite instead
    if [[ ! -e "$jhomercfile" ]]; then
        # create the rc file and add the exports
        print "\n# set by $0\n$java_home_export\n$java_version_export" > "$jhomercfile"
    else
        # make a backup copy of the rc file appending a timestamp extension
        cp "$jhomercfile" "$jhomercfile.$timestamp"
        
        # append it to the end
        print "\n# set by $0\n$java_home_export\n$java_version_export" >> "$jhomercfile"
    fi
    
    # now load it into the current environment
    source "$jhomercfile"
    print "Corretto 8 is now the active Java version."
}

uninstall_corretto() {
    #TODO: emm 2023-02-01
}

# install/update IntelliJ

install_intellij() {
    pushd ~/Downloads
    
    print "\n"
    print "Downloading latest IntelliJ Community Edition .dmg to `pwd`..."
    jetbrainsdmg="jetbrains.dmg"
    curl -L $curl_progress "$jetbrainsurl" -o "$jetbrainsdmg"

    # based loosely on https://stackoverflow.com/a/55869632
    print "Mounting .dmg..."
    volume=$(hdiutil attach -nobrowse "$jetbrainsdmg" | tail -n1 | cut -f3-; exit ${PIPESTATUS[0]})
    print "Copying IntelliJ app to /Applications folder..."
    rsync -a "$volume"/*.app "/Applications/"; synced=$?
    if [[ $synced -eq 0 ]]; then
        print "IntelliJ app successfully installed in /Applications folder"
    else
        print "Failed to install IntelliJ app in /Applications folder, rsync exit code $synced"
    fi
    print "Unmounting .dmg..."
    hdiutil detach -force -quiet "$volume"; detached=$?
    if [[ $detached -eq 0 ]]; then
        print "Successfully unmounted IntelliJ install disk image"
    else
        print "Failed to unmount IntelliJ install disk image--please do it manually in Disk Utility"
    fi
    print "Deleting .dmg..."
    rm -f "$jetbrainsdmg"
    
    popd
}

uninstall_intellij() {
    #TODO: emm 2023-02-01
}

# install/update MacPorts

install_macports() {
    # If we're not in an interactive shell, we can't ask questions or wait for input, so we
    # kind of have to assume this has all been taken care of manually beforehand. Most likely,
    # it means we're running as a Run Script Build Phase in Xcode anyway.

    if [[ -t 0 ]]; then
        pushd ~/Downloads
    
        print "\n"
        print "Downloading MacPorts installer .pkg for macOS Ventura to `pwd`..."
        macportspkgurl="https://github.com/macports/macports-base/releases/download/v2.8.1/MacPorts-2.8.1-13-Ventura.pkg"
        macportspkg="MacPorts.pkg"
        curl -L $curl_progress "$macportspkgurl" -o "$macportspkg"
        open "$macportspkg"
        print "\n"
        read -q 'anyKey?When the installer package finishes installing MacPorts, hit any key to continue: '

        print "Deleting .pkg..."
        rm -f "$macportspkg"
        
        popd
    fi
}

uninstall_macports() {
    #TODO: emm 2023-03-10
}

# install (a) MacPort(s)
port_install() {
    args=()
    while (( $# )); do
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

# install/update MySQL

# check for/create fork of BridgeServer2

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
    fork_mtb
    
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

fork_mtb() {
    # check if the repo already exists; if not, clone and then fork it
    if [[ ! -e "$REPOHOME/mtb" ]]; then
        pushd $REPOHOME
        /opt/local/bin/gh repo clone Sage-Bionetworks/mtb
        pushd mtb
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

if [[ `whoami` != root ]]; then
    print "Please run this script as root or with sudo (e.g. by copying the following\n"
    print "line, pasting it into a Terminal window, and hitting return or enter):\n"
    print "cd `pwd`; sudo zsh $@"
    exit 1
fi

# parse command line options
zparseopts -D -E -F -a install_flags - x+ -xcode+ m+ -macports+ g+ -gh+ i+ -iOS+ a+ -android+\
        b+ -bridge+ w+ -web+ || exit 1

# remove first -- or -
end_opts=$@[(i)(--|-)]
set -- "${@[0,end_opts-1]}" "${@[end_opts+1,-1]}"

# set up path to prioritize MacPorts binaries for the duration of the script
macPortsBin=/opt/local/bin
PATH="${macPortsBin}:${PATH}"

# set up where to clone GitHub repos
#TODO: Figure out where to default this to
REPOHOME="/Volumes/Tereshkova/Development/Sage"

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
    

print Done running $0
