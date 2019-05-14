#!/bin/bash
# Author: Jrohy
# Github: https://github.com/Jrohy/docker-install

OFFLINE_FILE=""

DOWNLOAD_URL="https://download.docker.com/linux/static/stable/x86_64/"

LATEST_VERSION_CHECK="https://api.github.com/repos/docker/docker-ce/releases/latest"

COMPLETION_FILE="https://raw.githubusercontent.com/docker/cli/master/contrib/completion/bash/docker"

# cancel centos alias
[[ -f /etc/redhat-release ]] && unalias -a

#######color code########
RED="31m"      
GREEN="32m"  
YELLOW="33m" 
BLUE="36m"
FUCHSIA="35m"

colorEcho(){
    COLOR=$1
    echo -e "\033[${COLOR}${@:2}\033[0m"
}

getFullPath() {
   local PWD=`pwd`
   if [ -d $1 ]; then
      cd $1
   elif [ -f $1 ]; then
      cd `dirname $1`
   else
      cd
   fi
   echo $(cd ..; cd -)
   cd ${PWD} >/dev/null
}

checkFile(){
    local FILE=$1
    if [[ ! -e $FILE ]];then
        colorEcho $RED "$FILE file not exist!\n"
        exit 1
    elif [[ ! -f $FILE ]];then
        colorEcho $RED "$FILE not a file!\n"
        exit 1
    fi

    FILE_NAME=$(echo ${FILE##*/})
    FILE_PATH=$(getFullPath $FILE)
    if [[ !  $FILE_NAME =~ ".tgz" || !  $FILE_NAME =~ ".tar.gz" ]];then
        colorEcho $RED "$FILE not a tgz file!\n"
        echo -e "please download docker binary file: $(colorEcho $FUCHSIA $DOWNLOAD_URL)\n"
        colorEcho $ "$FILE not a tgz file!\n"
        exit 1
    fi
}

#######get params#########
while [[ $# > 0 ]];do
    KEY="$1"
    case $KEY in
        -f|--file=)
        OFFLINE_FILE="$2"
        checkFile $OFFLINE_FILE
        shift
        ;;
        -h|--help)
        echo "Usage: $0 [OPTIONS]"
        echo "Options:"
        echo "  -f [file_path]/--file=[file_path]: offline tgz file path"
        echo "  -h, --help: find help"
        echo "Example:  $0 -f docker-18.09.tgz"
        echo "Docker binary download link:  $(colorEcho $FUCHSIA $DOWNLOAD_URL)"
        exit 0
        shift # past argument
        ;; 
        *)
                # unknown option
        ;;
    esac
    shift # past argument or value
done
#############################

checkSys() {
    # check os
    if [[ -e /etc/redhat-release ]];then
        if [[ $(cat /etc/redhat-release | grep Fedora) ]];then
            OS='Fedora'
            PACKAGE_MANAGER='dnf'
        else
            OS='CentOS'
            PACKAGE_MANAGER='yum'
        fi
    elif [[ $(cat /etc/issue | grep Debian) ]];then
        OS='Debian'
        PACKAGE_MANAGER='apt-get'
    elif [[ $(cat /etc/issue | grep Ubuntu) ]];then
        OS='Ubuntu'
        PACKAGE_MANAGER='apt-get'
    else
        colorEcho ${RED} "Not support OS, Please reinstall OS and retry!"
        exit 1
    fi
}

writeService(){
        cat > /usr/lib/systemd/system/docker.service << EOF
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network-online.target firewalld.service
Wants=network-online.target
 
[Service]
Type=notify
# the default is not to use systemd for cgroups because the delegate issues still
# exists and systemd currently does not support the cgroup feature set required
# for containers run by docker
ExecStart=/usr/bin/dockerd
ExecReload=/bin/kill -s HUP $MAINPID
# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
# Uncomment TasksMax if your systemd version supports it.
# Only systemd 226 and above support this version.
#TasksMax=infinity
TimeoutStartSec=0
# set delegate yes so that systemd does not reset the cgroups of docker containers
Delegate=yes
# kill only the docker process, not all processes in the cgroup
KillMode=process
# restart the docker process if it exits prematurely
Restart=on-failure
StartLimitBurst=3
StartLimitInterval=60s
 
[Install]
WantedBy=multi-user.target
EOF
}


dependentInstall(){
    if [[ ${OS} == 'CentOS' || ${OS} == 'Fedora' ]];then
        ${PACKAGE_MANAGER} install bash-completion -y
    else
        ${PACKAGE_MANAGER} update
        ${PACKAGE_MANAGER} install bash-completion -y
    fi
}

onlineInstall(){
    dependentInstall
    LASTEST_VERSION=$(curl -H 'Cache-Control: no-cache' -s "$LATEST_VERSION_CHECK" | grep 'tag_name' | cut -d\" -f4 | sed 's/v//g')
    wget $DOWNLOAD_URL/docker-$LASTEST_VERSION.tgz
    [[ $? != 0 ]] && colorEcho ${RED} "Fail download docker-$LASTEST_VERSION.tgz!" && exit 1
    tar xzvf docker-$LASTEST_VERSION.tgz
    cp -rf docker/* /usr/bin/
    rm -rf docker
    curl -L $COMPLETION_FILE -o /etc/bash_completion.d/docker
    chmod +x /etc/bash_completion.d/docker
    source /etc/bash_completion.d/docker
}

offlineInstall(){
    local ORIGIN_PATH=$(pwd)
    cd $FILE_PATH
    tar xzvf $FILE_NAME
    cp -rf docker/* /usr/bin/
    rm -rf docker
    cd ${ORIGIN_PATH} >/dev/null
    if [[ -e docker.bash || -e $FILE_PATH/docker.bash ]];then
        [[ -e docker.bash ]] && COMPLETION_FILE_PATH=`getFullPath docker.bash` || COMPLETION_FILE_PATH=$FILE_PATH
        cp -f $COMPLETION_FILE_PATH/docker.bash /etc/bash_completion.d/docker
        chmod +x /etc/bash_completion.d/docker
        source /etc/bash_completion.d/docker
    fi
}

main(){
    checkSys
    [[ $OFFLINE_FILE ]] && offlineInstall || onlineInstall
    writeService
    systemctl daemon-reload
    systemctl enable docker.service
    systemctl restart docker
    colorEcho $GREEN "docker install success!"
}

main