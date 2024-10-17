FROM kalilinux/kali-rolling AS builder
MAINTAINER Daniel Guerra

# Install packages

ENV DEBIAN_FRONTEND=noninteractive
ARG DEBIAN_VERSION_FOR_MIRORR="bookworm"
RUN echo "deb-src http://http.kali.org/kali kali-rolling main non-free contrib" | tee -a /etc/apt/sources.list
RUN echo "deb http://ftp.debian.org/debian $DEBIAN_VERSION_FOR_MIRORR main" >> /etc/apt/sources.list.d/debian-$DEBIAN_VERSION_FOR_MIRORR.list
RUN apt-get -y update && apt-get -yy dist-upgrade
ENV BUILD_DEPS="git autoconf pkg-config libssl-dev libpam0g-dev \
    libx11-dev libxfixes-dev libxrandr-dev nasm xsltproc flex \
    bison libxml2-dev dpkg-dev libcap-dev libxkbfile-dev"
ENV BUILD_DEPS2="liblirc-dev"
RUN apt-get -yy install  sudo apt-utils software-properties-common $BUILD_DEPS $BUILD_DEPS2


# Build xrdp

WORKDIR /tmp
RUN apt-get source pulseaudio
RUN apt-get build-dep -yy pulseaudio
RUN mv /tmp/pulseaudio-* /tmp/pulseaudio-11.1
WORKDIR /tmp/pulseaudio-11.1
RUN dpkg-buildpackage -rfakeroot -uc -b
WORKDIR /tmp
RUN git clone --branch devel --recursive https://github.com/neutrinolabs/xrdp.git
WORKDIR /tmp/xrdp
RUN ./bootstrap
RUN ./configure
RUN make
RUN make install
WORKDIR /tmp
RUN  apt -yy install libpulse-dev
RUN git clone --recursive https://github.com/neutrinolabs/pulseaudio-module-xrdp.git
WORKDIR /tmp/pulseaudio-module-xrdp
RUN ./bootstrap && ./configure PULSE_DIR=/tmp/pulseaudio-11.1
RUN make
RUN mkdir -p /tmp/so
RUN cp src/.libs/*.so /tmp/so

FROM kalilinux/kali-rolling
ARG ADDITIONAL_PACKAGES=""
ENV ADDITIONAL_PACKAGES=${ADDITIONAL_PACKAGES}
ENV TZ="Etc/UTC"
ENV DEBIAN_FRONTEND=noninteractive
COPY --from=builder /etc/apt/sources.list.d/debian*.list /etc/apt/sources.list.d/
RUN apt update && apt -y dist-upgrade && apt install -y \
  ca-certificates \
  crudini \
  dbus-x11 \
  kali-desktop-xfce \
  less \
  locales \
  openssh-server \
  pulseaudio \
  sudo \
  supervisor \
  uuid-runtime \
  vim \
  wget \
  xauth \
  xautolock \
  xorgxrdp \
  xprintidle \
  xrdp \
  tzdata \
  $ADDITIONAL_PACKAGES && \
  apt-get remove -y light-locker xscreensaver && \
  apt-get autoremove -yy && \
  rm -rf /var/cache/apt /var/lib/apt/lists && \
  mkdir -p /var/lib/xrdp-pulseaudio-installer
COPY --from=builder /tmp/so/module-xrdp-source.so /var/lib/xrdp-pulseaudio-installer
COPY --from=builder /tmp/so/module-xrdp-sink.so /var/lib/xrdp-pulseaudio-installer
ADD bin /usr/bin
ADD etc /etc
ADD autostart /etc/xdg/autostart

# Configure
RUN if [ ! -d "/var/run/dbus" ]; then mkdir /var/run/dbus; fi
RUN cp /etc/X11/xrdp/xorg.conf /etc/X11 && \
  sed -i "s/console/anybody/g" /etc/X11/Xwrapper.config && \
  sed -i "s/xrdp\/xorg/xorg/g" /etc/xrdp/sesman.ini && \
  locale-gen en_US.UTF-8 && \
  echo "#!/bin/sh" > /usr/bin/start-pulseaudio-x11  && \
  echo "pulseaudio -D --enable-memfd=True" >> /usr/bin/start-pulseaudio-x11  && \
  echo "xfce4-session" >> /etc/skel/.Xclients && \
  cp -r /etc/ssh /ssh_orig && \
  rm -rf /etc/ssh/* && \
  rm -rf /etc/xrdp/rsakeys.ini /etc/xrdp/*.pem && \
  ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Docker config
VOLUME ["/etc/ssh","/home"]
EXPOSE 3389 22 9001
ENTRYPOINT ["/usr/bin/docker-entrypoint.sh"]
CMD ["supervisord"]
