FROM ubuntu:20.04

ARG UID=1000
ARG GID=1000
ARG K8_VERSION=v1.20.4
ENV USER locker_user
ENV USER_HOME /home/$USER

RUN apt-get update && apt-get install -y curl

RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/${K8_VERSION}/bin/linux/amd64/kubectl
RUN chmod +x ./kubectl
RUN mv ./kubectl /usr/local/bin

RUN groupadd -f -g $GID users2
RUN useradd -u $UID -g $GID $USER

RUN mkdir -p $USER_HOME \
  && chown -R $USER $USER_HOME

USER locker_user