
# OpenRoad development environment in docker container
This page describes how to set up a OpenRoad development environment inside an Ubuntu 22.04 docker container. This allows for a consistent environment and will not bloat your host system with the dependencies for OpenRoad. The container creation can probably be automated easily with a dockerfile, but for initial development the manual way described below is also bearable.

## Setup Container
First create a new Ubuntu 22.04 docker container and bind mount the home directory for convenience. Replace `<MOUNT_PATH_FOR_DOCKER_HOME>` with a absolute path on your host system where you want the docker home directory to be mounted and `<YOUR_USER_NAME>` with the username you are using on your host system
```
docker run -it --name openroad-ubuntu -e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix -v <MOUNT_PATH_FOR_DOCKER_HOME>:/home/<YOUR_USER_NAME> -w /home/<YOUR_USER_NAME> ubuntu:22.04 /bin/bash
```

You should get a root shell inside the container. Execute the following commands to install OpenRoad. Do not forget to replace `<YOUR_USER_NAME>`.
```
apt update && apt upgrade -y
apt install -y git sudo
unminimize
cd /home/<YOUR_USER_NAME>
useradd <YOUR_USER_NAME>
su <YOUR_USER_NAME>
git clone --recursive https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts
exit # brings you back to root in container
cd OpenROAD-flow-scripts
git config --global --add safe.directory '*'
export SUDO_USER=root
./setup.sh # This might need multiple tries
./build_openroad.sh --local # This might need multiple tries
```

Install cocotb for testing and simulation:
```
apt install iverilog gtkwave
pip install cocotb cocotb-test
```

For development purposes you might also want to install [netlistsvg](https://github.com/nturley/netlistsvg) (optional):
```
apt install npm
npm install -g netlistsvg
```

Verify installation (in container)
```
su <YOUR_USER_NAME>
cd ~/OpenROAD-flow-scripts
source ./env.sh
yosys -help
openroad -help
cd flow
make
make gui_final
```

If you get an error when starting a gui application from inside the container you need to execute the following command on your host OS to add the docker user to the X-Server backend.
```
xhost +local:docker
```

## Start container
You can always get a shell inside your container with the following command:
```
docker exec -it openroad-ubuntu sudo -u <YOUR_USER_NAME> bash
```

If you need a root shell (to install packages for example):
```
docker exec -it openroad-ubuntu sudo -u <YOUR_USER_NAME> bash
```

If the container is not running you may start it with:
```
docker start openroad-ubuntu
```

## Backup Container
You can commit the container to your local container registry and save it as a tar file.
```
docker commit openroad-ubuntu openroad-ubuntu:latest
docker save -o openroad-ubuntu-image.tar openroad-ubuntu:latest
```
