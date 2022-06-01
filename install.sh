#!/bin/bash
# Author: Jrohy
# Github: https://github.com/Jrohy/docker-install

offline_file=""

standard_mode=0

can_google=0

#######color code########
red="31m"      
green="32m"  
yellow="33m" 
blue="36m"
fuchsia="35m"

download_url="https://download.docker.com/linux/static/stable/$(uname -m)"

latest_version_check="https://api.github.com/repos/moby/moby/releases/latest"

completion_file="https://raw.githubusercontent.com/docker/cli/master/contrib/completion/bash/docker"

# cancel centos alias
[[ -f /etc/redhat-release ]] && unalias -a

sysctl_list=(
    "net.ipv4.ip_forward"
    "net.bridge.bridge-nf-call-iptables"
    "net.bridge.bridge-nf-call-ip6tables"
)

color_echo(){
    local color=$1
    echo -e "\033[${color}${@:2}\033[0m"
}

ip_is_connect(){
    ping -c2 -i0.3 -W1 $1 &>/dev/null
    if [ $? -eq 0 ];then
        return 0
    else
        return 1
    fi
}

full_path() {
   local pwd=`pwd`
   if [ -d $1 ]; then
      cd $1
   elif [ -f $1 ]; then
      cd `dirname $1`
   else
      cd
   fi
   echo $(cd ..; cd -)
   cd ${pwd} >/dev/null
}

check_file(){
    local file=$1
    if [[ ! -e $file ]];then
        color_echo $red "$file file not exist!\n"
        exit 1
    elif [[ ! -f $file ]];then
        color_echo $red "$file not a file!\n"
        exit 1
    fi

    file_name=$(echo ${file##*/})
    file_path=$(full_path $file)
    if [[ !  $file_name =~ ".tgz" && !  $file_name =~ ".tar.gz" ]];then
        color_echo $red "$file not a tgz file!\n"
        echo -e "please download docker binary file: $(color_echo $fuchsia $download_url)\n"
        exit 1
    fi
}

#######get params#########
while [[ $# > 0 ]];do
    case "$1" in
        -f|--file=)
        offline_file="$2"
        check_file $offline_file
        shift
        ;;
        -s|--standard)
        standard_mode=1
        shift
        ;;
        -h|--help)
        echo "$0 [-h] [-f file]"
        echo "   -f, --file=[file_path]      offline tgz file path"
        echo "   -h, --help                  find help"
        echo "   -s, --standard              use 'get.docker.com' shell to install"
        echo ""
        echo "Docker binary download link:  $(color_echo $fuchsia $download_url)"
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

check_sys() {
    if [[ -z `command -v systemctl` ]];then
        color_echo ${red} "system must be have systemd!"
        exit 1
    fi
    if [[ -z `uname -m|grep 64` ]];then
        color_echo ${red} "docker only support 64-bit system!"
        exit 1
    fi
    # check os
    if [[ `command -v apt-get` ]];then
        package_manager='apt-get'
    elif [[ `command -v dnf` ]];then
        package_manager='dnf'
    elif [[ `command -v yum` ]];then
        package_manager='yum'
    else
        color_echo $red "Not support OS!"
        exit 1
    fi
}

write_service(){
        mkdir -p /usr/lib/systemd/system/
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

dependent_install(){
    if [[ ${package_manager} == 'yum' || ${package_manager} == 'dnf' ]];then
        ${package_manager} install bash-completion wget iptables -y
    else
        ${package_manager} update
        ${package_manager} install bash-completion wget iptables -y
    fi
}

online_install(){
    dependent_install
    latest_version=$(curl -H 'Cache-Control: no-cache' -s "$latest_version_check" | grep 'tag_name' | cut -d\" -f4 | sed 's/v//g')
    wget $download_url/docker-$latest_version.tgz
    if [[ $? != 0 ]];then
        color_echo ${red} "Fail download docker-$latest_version.tgz!"
        exit 1
    fi
    tar xzvf docker-$latest_version.tgz
    cp -rf docker/* /usr/bin/
    rm -rf docker docker-$latest_version.tgz
    curl -L $completion_file -o /usr/share/bash-completion/completions/docker
    chmod +x /usr/share/bash-completion/completions/docker
    source /usr/share/bash-completion/completions/docker
}

offline_install(){
    local origin_path=$(pwd)
    cd $file_path
    tar xzvf $file_name
    cp -rf docker/* /usr/bin/
    rm -rf docker
    cd ${origin_path} >/dev/null
    if [[ -e docker.bash || -e $file_path/docker.bash ]];then
        [[ -e docker.bash ]] && completion_file_path=`full_path docker.bash` || completion_file_path=$file_path
        cp -f $completion_file_path/docker.bash /usr/share/bash-completion/completions/docker
        chmod +x /usr/share/bash-completion/completions/docker
        source /usr/share/bash-completion/completions/docker
    fi
}

standard_install(){
    dependent_install
    # Centos8
    if [[ $package_manager == 'dnf' && `cat /etc/redhat-release |grep CentOS` ]];then
        ## see https://teddysun.com/587.html
        dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
        # install lastest containerd
        local containerd_url="https://download.docker.com/linux/centos/7/x86_64/stable/Packages/"
        local package_list="`curl -s $containerd_url`"
        local containerd_index=`echo "$package_list"|grep containerd|awk -F' {2,}' '{print $2}'|awk '{printf("%s %s\n", $1, $2)}'|sort -r|head -n 1`
        dnf install -y $containerd_url/`echo "$package_list"|grep "$containerd_index"|awk -F '"' '{print $2}'`
        dnf install -y --nobest docker-ce
    else
        ip_is_connect www.google.com
        [[  $? -eq 0 ]] && can_google=1
        while :
        do
            if [[  $can_google == 1 ]]; then
                sh <(curl -sL https://get.docker.com)
            else
                sh <(curl -sL https://get.docker.com) --mirror Aliyun
            fi
            [[ $? -eq 0 ]] && break
        done
    fi
}

set_sysctl(){
    for conf in ${sysctl_list[@]}
    do
        check=`sysctl $conf 2>/dev/null`
        if [[ `echo $check` =~ "0" || -z `echo $check` ]];then
            if [[ `cat /etc/sysctl.conf` =~ "$conf" ]];then
                sed -i "s/^$conf.*/$conf=1/g" /etc/sysctl.conf
            else
                echo "$conf=1" >> /etc/sysctl.conf
            fi
            sysctl -p >/dev/null 2>&1
        fi
    done
}

main(){
    check_sys
    if [[ $standard_mode == 1 ]];then
        standard_install
    else
        [[ $offline_file ]] && offline_install || online_install
        write_service
        systemctl daemon-reload
    fi
    set_sysctl
    systemctl enable docker.service
    systemctl restart docker
    echo -e "docker $(color_echo $blue $(docker info|grep 'Server Version'|awk '{print $3}')) install success!"
}

main