FROM ghcr.io/lizenzfass78851/ubuntu-xrdp:kali-light

RUN apt update && apt dist-upgrade -yy && \ 
  apt install -y \
  kali-linux-default && \
  apt-get autoremove -yy && \
  rm -rf /var/cache/apt /var/lib/apt/lists

# Docker config
VOLUME ["/etc/ssh","/home"]
EXPOSE 3389 22 9001
ENTRYPOINT ["/usr/bin/docker-entrypoint.sh"]
CMD ["supervisord"]
