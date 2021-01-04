FROM debian:10

ARG UID=1000
ARG GID=1000
ENV USER locker_user
ENV USER_HOME /home/$USER

RUN apt-get update && apt-get install -y \
    openssh-server uuid-runtime 2>/dev/null

RUN groupadd -f -g $GID users2
RUN useradd -u $UID -g $GID $USER \
  && sed -i s/#PermitRootLogin.*/PermitRootLogin\ yes/ /etc/ssh/sshd_config

COPY ./start.sh /start.sh

RUN mkdir -p $USER_HOME/.ssh /run/sshd \
  && chown -R $USER $USER_HOME

EXPOSE 22
ENTRYPOINT ["/usr/sbin/sshd", "-D"]