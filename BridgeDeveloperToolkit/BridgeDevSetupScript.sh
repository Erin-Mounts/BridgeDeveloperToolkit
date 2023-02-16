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
# Install/update iOS dev environment (Xcode, including additional tools)
#
##################################################################################################

install_ios_dev_tools() {
    # If we're not in an interactive shell, we can't ask questions or wait for input, so we
    # kind of have to assume this has all been taken care of manually beforehand. Most likely,
    # it means we're running as a Run Script Build Phase in Xcode anyway.

    if [[ -t 0 ]]; then
        print '==========================================='
        print '= Installing/updating iOS dev environment ='
        print '==========================================='
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
            xcodeInstall=`mdfind -name 'Xcode.app' 2>/dev/null`; open $xcodeInstall
            print "\n"
            read -q 'anyKey?Please install Xcode additional tools. When installation has finished, hit any key to continue: '
        fi
    else
        print 'If you need to install or update the iOS development environment, please open\
        a new Terminal window, copy and paste in the following line, then hit return or enter:)'
        print "cd `pwd`; zsh $0"
    fi
}

uninstall_ios_dev_tools() {
    # TODO emm 2023-02-01
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
}

uninstall_bridge_dev_tools() {
    uninstall_corretto
    uninstall_intellij
}

# install/update Corretto 8
install_corretto() {
    print "\n"
    print "Downloading latest Corretto 8 .pkg..."
    corretto8pkg="corretto.pkg"
    curl -L $curl_progress "$corretto8url" -o "$corretto8pkg"

    open "$corretto8pkg"
    read -q 'anyKey?Please follow the installer prompts to install Corretto 8. When installation has finished, hit any key to continue: '

    print "Deleting .pkg..."
    rm -f "$corretto8pkg"

    # check if corretto is being overridden by a "newer" Java version.
    # (Oracle uses a different build number scheme for its Internet applet plug-in which makes it look newer
    # than even later builds of the same minor revision.)
    jhome=`/usr/libexec/java_home`
    if [[ ! ("$jhome" =~ corretto) ]]; then
        # set $JAVA_HOME to corretto in ~/.zshenv
        jhomercfile="~/.zshenv"
        print "A higher-numbered Java version is already installed. Setting JAVA_HOME in \"$jhomercfile\"..."
        corretto_home="/usr/libexec/java_home -V 2>&1 | egrep -o '/.*corretto.*$'`
        java_home_export='export JAVA_HOME=$()
        if [[ ! -e "$jhomercfile" ]]; then
            # create the rc file and add the export
            print "\n# set by $0\n$corretto_export" > "$jhomercfile"
        else
            # append it to the end (leave any previous export there for if/when we remove this line)
            print "\n# set by $0\nexport JAVA_HOME=\"$corretto_home\"" >> "$jhomercfile"
        fi
        
        # now load it into the current environment
        source "$jhomercfile"
    fi
    print "Corretto 8 is now the active Java version."
}

uninstall_corretto() {
    # TODO emm 2023-02-01
}

# install/update IntelliJ

install_intellij() {
    print "\n"
    print "Downloading latest IntelliJ Community Edition .dmg..."
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
}

uninstall_intellij() {
    # TODO emm 2023-02-01
}

# install/update MacPorts

# install/update Maven

# install/update Redis

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
    # TODO emm 2023-02-01
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
}

uninstall_web_dev_tools() {
    # TODO emm 2023-02-01
}

#install_ios_dev_tools
install_bridge_dev_tools
#install_android_dev_tools
#install_web_dev_tools

print Done running $0
