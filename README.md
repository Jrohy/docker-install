# docker-install
![](https://img.shields.io/github/stars/Jrohy/docker-install.svg)
![](https://img.shields.io/github/forks/Jrohy/docker-install.svg) 
![](https://img.shields.io/github/license/Jrohy/docker-install.svg)  
auto install latest docker by online/offline (binaries install)

## Install/Update docker online
```
source <(curl -sL https://git.io/fj8OJ)
```

## Install/Update docker offline
```
./docker-install.sh -f /root/docker-18.09.6.tgz
```
bash-completion file **docker.bash** should put same directory with docker-install.sh  
offline file: https://download.docker.com/linux/static/stable/