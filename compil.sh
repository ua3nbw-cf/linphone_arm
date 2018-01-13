#!/bin/bash

# PLEASE EDIT NEXT LINES TO DEFINE YOUR OWN CONFIGURATION

LOGNAME="linphone.log" # Name of the log file
LOGPATH="/var/log/" # Path where the logfile will be stored be sure to add a / at the end of the path

# *************************************
#
# PLEASE DO NOT MODIFY THE LINES BELOW
#
# *************************************




# linphone_arm  GIT URL
LINPHONE_ARM_ARCHIVE="https://github.com/ua3nbw-cf/linphone_arm.git"


### PKG Vars ###
PKG_MANAGER="apt-get"
PKG_CACHE="/var/lib/apt/lists/"
UPDATE_PKG_CACHE="${PKG_MANAGER} update"
PKG_INSTALL="${PKG_MANAGER} --yes install"
PKG_UPGRADE="${PKG_MANAGER} --yes upgrade"
PKG_DIST_UPGRADE="apt dist-upgrade -y --force-yes"
PKG_COUNT="${PKG_MANAGER} -s -o Debug::NoLocking=true upgrade | grep -c ^Inst || true"
#COLORS
# Reset
Color_Off='\033[0m'       # Text Reset

# Regular Colors
Red='\033[0;31m'          # Red
Green='\033[0;32m'        # Green
Yellow='\033[0;33m'       # Yellow
Purple='\033[0;35m'       # Purple
Cyan='\033[0;36m'         # Cyan

#################################################
# Set variables
#################################################


TIME_START=$(date +%s)
TIME_STAMP_START=(`date +"%T"`)

DATE_LONG=$(date +"%a, %d %b %Y %H:%M:%S %z")
DATE_SHORT=$(date +%Y%m%d)

check_returned_code() {
    RETURNED_CODE=$@
    if [ $RETURNED_CODE -ne 0 ]; then
        display_message ""
        display_message "Something went wrong with the last command. Please check the log file"
        display_message ""
        exit 1
    fi
}

display_message() {
    MESSAGE=$@
    # Display on console
    echo "::: $MESSAGE"
    # Save it to log file
    echo "::: $MESSAGE" >> $LOGPATH$LOGNAME
}

execute_command() {
    display_message "$3"
    COMMAND="$1 >> $LOGPATH$LOGNAME 2>&1"
    eval $COMMAND
    COMMAND_RESULT=$?
    if [ "$2" != "false" ]; then
        check_returned_code $COMMAND_RESULT
    fi
}

prepare_logfile() {
    echo "::: Preparing log file"
    if [ -f $LOGPATH$LOGNAME ]; then
        echo "::: Log file already exists. Creating a backup."
        execute_command "mv $LOGPATH$LOGNAME $LOGPATH$LOGNAME.`date +%Y%m%d.%H%M%S`"
    fi
    echo "::: Creating the log file"
    execute_command "touch $LOGPATH$LOGNAME"
    display_message "Log file created : $LOGPATH$LOGNAME"
    display_message "'sudo tail -f $LOGPATH$LOGNAME' in a new console to get installation details"
echo -e "$Cyan \n sudo tail -f $LOGPATH$LOGNAME $Color_Off \n"
}


prepare_install() {
    # Prepare the log file
    prepare_logfile
    #systemctl stop bluez
    #apt-get remove bluez -y  > /dev/null 2>&1

}

check_root() {
    # Must be root to install the hotspot
    echo ":::"
    if [[ $EUID -eq 0 ]];then
        echo "::: You are root - OK"
    else
        echo "::: sudo will be used for the install."
        # Check if it is actually installed
        # If it isn't, exit because the install cannot complete
        if [[ $(dpkg-query -s sudo) ]];then
            export SUDO="sudo"
            export SUDOE="sudo -E"
        else
            echo "::: Please install sudo or run this as root."
            exit 1
        fi
    fi
}

jumpto() {
    label=$1
    cmd=$(sed -n "/$label:/{:a;n;p;ba};" $0 | grep -v ':$')
    eval "$cmd"
    exit
}

verifyFreeDiskSpace() {
    # Needed free space
    local required_free_megabytes=500
    # If user installs unattended-upgrades we will check for 500MB free
    echo ":::"
    echo -n "::: Verifying free disk space ($required_free_megabytes Kb)"
    local existing_free_megabytes=$(df -Pk | grep -m1 '\/$' | awk '{print $4}')

    # - Unknown free disk space , not a integer
    if ! [[ "${existing_free_megabytes}" =~ ^([0-9])+$ ]]; then
        echo ""
        echo "::: Unknown free disk space!"
        echo "::: We were unable to determine available free disk space on this system."
        echo "::: You may continue with the installation, however, it is not recommended."
        read -r -p "::: If you are sure you want to continue, type YES and press enter :: " response
        case $response in
            [Y][E][S])
                ;;
            *)
                echo "::: Confirmation not received, exiting..."
                exit 1
                ;;
        esac
    # - Insufficient free disk space
    elif [[ ${existing_free_megabytes} -lt ${required_free_megabytes} ]]; then
        echo ""
        echo "::: Insufficient Disk Space!"
        echo "::: Your system appears to be low on disk space. Pi-HotSpot recommends a minimum of $required_free_megabytes MegaBytes."
        echo "::: You only have ${existing_free_megabytes} MegaBytes free."
        echo ":::"
        echo "::: If this is a new install on a Raspberry Pi you may need to expand your disk."
        echo "::: Try running 'sudo raspi-config', and choose the 'expand file system option'"
        echo ":::"
        echo "::: After rebooting, run this installation again."

        echo "Insufficient free space, exiting..."
        exit 1
    else
        echo " - OK"
    fi
}

update_package_cache() {
  timestamp=$(stat -c %Y ${PKG_CACHE})
  timestampAsDate=$(date -d @"${timestamp}" "+%b %e")
  today=$(date "+%b %e")

  if [ ! "${today}" == "${timestampAsDate}" ]; then
    #update package lists
    echo ":::"
    if command -v debconf-apt-progress &> /dev/null; then
        $SUDO debconf-apt-progress -- ${UPDATE_PKG_CACHE}
    else
        $SUDO ${UPDATE_PKG_CACHE} &> /dev/null
    fi
  fi
}

notify_package_updates_available() {
  echo ":::"
  echo -n "::: Checking ${PKG_MANAGER} for upgraded packages...."
  updatesToInstall=$(eval "${PKG_COUNT}")
  echo " done!"
  echo ":::"
  if [[ ${updatesToInstall} -eq "0" ]]; then
    echo "::: Your system is up to date! Continuing with linphone installation..."
  else
    echo "::: There are ${updatesToInstall} updates available for your system!"
    echo ":::"
execute_command "apt-get upgrade -y --force-yes" true "Upgrading the packages. Please be patient. 'sudo tail -f $LOGPATH$LOGNAME' in a new console to get installation details"
    display_message "Please reboot and run the script again"
    exit 1
  fi
}

package_check_install() {
    dpkg-query -W -f='${Status}' "${1}" 2>/dev/null | grep -c "ok installed" || ${PKG_INSTALL} "${1}"
}

LINPHONE_ARM_DEPS_START=( apt-transport-https debconf-utils)
LINPHONE_ARM_DEPS_PYTHON=( apt-utils   )
LINPHONE_ARM_DEPS=( cmake libtool intltool doxygen graphviz python-setuptools libsqlite3-dev libantlr3c-dev antlr3 libopus-dev  libspeexdsp-dev libasound2-dev libxml2-dev )

install_dependent_packages() {

  declare -a argArray1=("${!1}")

  if command -v debconf-apt-progress &> /dev/null; then
    $SUDO debconf-apt-progress -- ${PKG_INSTALL} "${argArray1[@]}"
  else
    for i in "${argArray1[@]}"; do
      echo -n ":::    Checking for $i..."
      $SUDO package_check_install "${i}" &> /dev/null
      echo " installed!"
    done
  fi
}

check_root
 
#DEBIAN_VERSION=`cat /etc/*-release | grep VERSION_ID | awk -F= '{print $2}' | sed -e 's/^"//' -e 's/"$//'`
#if [[ $DEBIAN_VERSION -ne 9 ]];then
#       display_message ""
#       display_message "This script is used to get installed on Debian GNU/Linux 9 (stretch)"
#      display_message ""
#   exit 1
#fi

verifyFreeDiskSpace

prepare_install

update_package_cache

notify_package_updates_available

install_dependent_packages LINPHONE_ARM_DEPS_START[@]


#execute_command "dpkg --purge --force-all hostapd" true "Remove old configuration of hostapd"

DEBIAN_FRONTEND=noninteractive
install_dependent_packages LINPHONE_ARM_DEPS[@]

execute_command "easy_install pip" true "easy_install pip"
execute_command "pip install pystache" true "pip install pystache"
execute_command "pip install six" true "pip install six"

execute_command "cd externals/mbedtls" true "Compiling mbedtls"
execute_command "cmake -DUSE_SHARED_MBEDTLS_LIBRARY=On . -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_PREFIX_PATH=/usr/local/lib" true "cmake"
execute_command "make -j4" true "make"
execute_command "make install" true "make install"
echo -e "$Green \n Install mbedtls$Color_Off \n"
cd ../..
execute_command "cd bcunit" true "Compiling bcunit"
execute_command "cmake .  -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_PREFIX_PATH=/usr/local/lib" true "cmake"
execute_command "make -j4" true "make"
execute_command "make install" true "make install"
echo -e "$Green \n Install bcunit$Color_Off \n"
cd ..
execute_command "cd bctoolbox" true "Compiling bctoolbox"
execute_command "cmake .  -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_PREFIX_PATH=/usr/local/lib  -DENABLE_SHARED=YES" true "cmake"
execute_command "make" true "make"
execute_command "make install" true "make install"
echo -e "$Green \n Install bctoolbox$Color_Off \n"
cd ..
execute_command "cd belle-sip" true "Compiling belle-sip"
execute_command "cmake .  -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_PREFIX_PATH=/usr/local/lib" true "cmake"
execute_command "make -j4" true "make"
execute_command "make install" true "make install"
echo -e "$Green \n Install belle-sip$Color_Off \n"
cd ..
execute_command "cd ortp" true "Compiling ortp"
execute_command "cmake .  -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_PREFIX_PATH=/usr/local/lib" true "cmake"
execute_command "make -j4" true "make"
execute_command "make install" true "make install"
echo -e "$Green \n Install ortp$Color_Off \n"
cd ..
execute_command "cd mediastreamer2" true "Compiling mediastreamer2"
execute_command "cmake .  -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_PREFIX_PATH=/usr/local/lib -DENABLE_VIDEO=NO -DENABLE_ALSA=YES -DENABLE_G729=NO" true "cmake"
execute_command "make -j4" true "make"
execute_command "make install" true "make install"
echo -e "$Green \n Install mediastreamer2$Color_Off \n"
cd ..
execute_command "cd belr" true "Compiling belr"
execute_command "cmake .  -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_PREFIX_PATH=/usr/local/lib" true "cmake"
execute_command "make -j4" true "make"
execute_command "make install" true "make install"
echo -e "$Green \n Install belr$Color_Off \n"
cd ..
execute_command "cd belcard" true "Compiling belcard"
execute_command "cmake .  -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_PREFIX_PATH=/usr/local/lib" true "cmake"
execute_command "make -j4" true "make"
execute_command "make install" true "make install"
echo -e "$Green \n Install belcard$Color_Off \n"
cd ..
execute_command "cd bzrtp" true "Compiling bzrtp"
execute_command "cmake .  -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_PREFIX_PATH=/usr/local/lib" true "cmake"
execute_command "make -j4" true "make"
execute_command "make install" true "make install"
echo -e "$Green \n Install bzrtp$Color_Off \n"
cd ..
execute_command "cd linphone" true "Compiling linphone"
execute_command "cmake .  -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_PREFIX_PATH=/usr/local/lib -DENABLE_VIDEO=NO -DENABLE_GTK_UI=NO -DENABLE_TUTORIALS=NO -DENABLE_DOC=NO -DENABLE_UNIT_TESTS=NO" true "cmake"
execute_command "make -j4" true "make"
execute_command "make install" true "make install"
echo -e "$Green \n Install linphone$Color_Off \n"
cd ..

display_message ""
display_message ""
display_message "Congratulation ! You now have your linphone ready !"
display_message ""


echo -e "- For the user management, please  to $Cyan linphonec $Color_Off"
amixer -c 0 -q set "Line Out"  100%+ unmute
amixer -c 0 -q set "DAC"  100%+ unmute







    #################################################
    # Cleanup
    #################################################

    # clean up dirs

    # note time ended
    time_end=$(date +%s)
    time_stamp_end=(`date +"%T"`)
    runtime=$(echo "scale=2; ($time_end-$TIME_START) / 60 " | bc)

    # output finish
    echo -e "\nTime started: ${TIME_STAMP_START}"
    echo -e "Time started: ${time_stamp_end}"
    echo -e "Total Runtime (minutes): $Red $runtime\n $Color_Off "

exit 0












 
