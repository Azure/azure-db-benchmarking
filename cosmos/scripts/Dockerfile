FROM ubuntu:20.04
RUN apt-get update && apt-get install -y openjdk-8-jdk net-tools vim
RUN apt-get -y install maven
RUN apt-get update && apt-get -y install git-all
RUN apt-get -y install dos2unix
RUN apt-get -y install curl
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash
RUN apt install -y wget
RUN wget https://aka.ms/downloadazcopy-v10-linux && tar -xvf downloadazcopy-v10-linux && cp ./azcopy_linux_amd64_*/azcopy /usr/bin/
RUN apt install -y jq
RUN apt-get install -y python3
RUN apt-get install sudo -y
RUN sudo apt-get install uuid-runtime
RUN adduser --disabled-password --gecos '' benchmarking
RUN adduser benchmarking sudo
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> \
/etc/sudoers
USER benchmarking
WORKDIR /home/benchmarking
RUN curl -H 'Cache-Control: no-cache, no-store' -o execute-kubernetes.sh https://raw.githubusercontent.com/Azure/azure-db-benchmarking/users/ratella/aks/cosmos/scripts/execute-kubernetes.sh
RUN chmod +x execute-kubernetes.sh