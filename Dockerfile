FROM ubuntu:24.04 AS builder
MAINTAINER Daniel Guerra

# Install packages

ENV DEBIAN_FRONTEND=noninteractive
RUN cp /etc/apt/sources.list.d/ubuntu.sources /etc/apt/sources.list.d/ubuntu-src.sources && \
  sed -i "s/deb/deb-src/g" /etc/apt/sources.list.d/ubuntu-src.sources
RUN apt-get -y update && apt-get -yy dist-upgrade
ENV BUILD_DEPS="git autoconf pkg-config libssl-dev libpam0g-dev \
    libx11-dev libxfixes-dev libxrandr-dev nasm xsltproc flex \
    bison libxml2-dev dpkg-dev libcap-dev libxkbfile-dev"
RUN apt-get -yy install  sudo apt-utils software-properties-common $BUILD_DEPS


# Build xrdp

WORKDIR /tmp
RUN apt-get source pulseaudio
RUN apt-get build-dep -yy pulseaudio
RUN mv /tmp/pulseaudio-* /tmp/pulseaudio-11.1
WORKDIR /tmp/pulseaudio-11.1
RUN dpkg-buildpackage -rfakeroot -uc -b
WORKDIR /tmp
RUN git clone --branch v0.10 --recursive https://github.com/neutrinolabs/xrdp.git
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

FROM ubuntu:24.04
ARG ADDITIONAL_PACKAGES=""
ENV ADDITIONAL_PACKAGES=${ADDITIONAL_PACKAGES}
ENV TZ="Etc/UTC"
ENV DEBIAN_FRONTEND=noninteractive
RUN apt update && apt install -y software-properties-common apt-utils
RUN echo -e '#!/bin/sh\nexit 1' | tee /usr/sbin/telinit
RUN apt -y dist-upgrade && apt install -y \
  ca-certificates \
  crudini \
  less \
  locales \
  openssh-server \
  pulseaudio \
  sudo \
  supervisor \
  uuid-runtime \
  vim \
  vlc \
  wget \
  xauth \
  xautolock \
  xfce4 \
  xfce4-clipman-plugin \
  xfce4-cpugraph-plugin \
  xfce4-netload-plugin \
  xfce4-screenshooter \
  xfce4-taskmanager \
  xfce4-terminal \
  xfce4-xkb-plugin \
  dbus-x11 \
  xorgxrdp \
  xprintidle \
  xrdp \
  tzdata \
  $ADDITIONAL_PACKAGES && \
  apt-get remove -y light-locker xscreensaver && \
  apt-get autoremove -yy && \
  rm -rf /var/cache/apt /var/lib/apt/lists && \
  mkdir -p /var/lib/xrdp-pulseaudio-installer
RUN install -d -m 0755 /etc/apt/keyrings && \
  wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- | tee /etc/apt/keyrings/packages.mozilla.org.asc && \
  gpg -n -q --import --import-options import-show /etc/apt/keyrings/packages.mozilla.org.asc | awk '/pub/{getline; gsub(/^ +| +$/,""); if($0 == "35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3") print "\nThe key fingerprint matches ("$0").\n"; else print "\nVerification failed: the fingerprint ("$0") does not match the expected one.\n"}' && \
  echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" | sudo tee -a /etc/apt/sources.list.d/mozilla.list && \
  printf 'Package: *\nPin: origin packages.mozilla.org\nPin-Priority: 1000\n' | sudo tee /etc/apt/preferences.d/mozilla && \
  echo 'Unattended-Upgrade::Allowed-Origins:: "packages.mozilla.org:mozilla";' | sudo tee /etc/apt/apt.conf.d/51unattended-upgrades-firefox && \
  apt update && apt install -y firefox && \
  rm -rf /var/cache/apt /var/lib/apt/lists
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
  echo "pulseaudio -D --enable-memfd=True" > /etc/skel/.Xsession && \
  echo "xfce4-session" >> /etc/skel/.Xsession && \
  cp -r /etc/ssh /ssh_orig && \
  rm -rf /etc/ssh/* && \
  rm -rf /etc/xrdp/rsakeys.ini /etc/xrdp/*.pem && \
  ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Docker config
VOLUME ["/etc/ssh","/home"]
EXPOSE 3389 22 9001
ENTRYPOINT ["/usr/bin/docker-entrypoint.sh"]
CMD ["supervisord"]
