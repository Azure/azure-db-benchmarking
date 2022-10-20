FROM ubuntu:20.04
RUN apt-get update && apt-get install -y openjdk-8-jdk net-tools vim
COPY ycsb-azurecosmos-binding-0.18.0-SNAPSHOT/ /usr/app/ycsb-azurecosmos-binding-0.18.0-SNAPSHOT/
COPY ./run.sh /usr/app/ycsb-azurecosmos-binding-0.18.0-SNAPSHOT/
COPY ./azure_file_share.sh /usr/app/ycsb-azurecosmos-binding-0.18.0-SNAPSHOT/
COPY ./azurecosmos.properties /usr/app/ycsb-azurecosmos-binding-0.18.0-SNAPSHOT/
WORKDIR /usr/app/ycsb-azurecosmos-binding-0.18.0-SNAPSHOT/
RUN pwd
RUN chmod +x run.sh
RUN chmod +x azure_file_share.sh
CMD /bin/sh ./run.sh