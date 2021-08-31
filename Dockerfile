# Postfix SMTP Relay

FROM debian:buster

ENV ARCH=armhf

EXPOSE 25 587 2525

# Preselections for installation
RUN set -x \
  && echo mail > /etc/hostname \
  && echo "postfix postfix/main_mailer_type string Internet site" >> preseed.txt \
  && echo "postfix postfix/mailname string mail.example.com" >> preseed.txt \
  && debconf-set-selections preseed.txt && rm preseed.txt \
  ;

# Install packages
RUN set -x \
  && export DEBIAN_FRONTEND=noninteractive \
  && apt-get update \
  && apt-get install -y --no-install-recommends postfix mailutils busybox-syslogd opendkim opendkim-tools libsasl2-modules sasl2-bin curl ca-certificates procps \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* \
  ;

# Install s6
RUN set -x \
  && S6_VERSION=2.10.0.3 \
  && S6_CHECKSUM=0891288b56a7afd12460f163d6968b5269e9816029a77765526e1267c032a64c \
  && EXECLINE_VERSION=2.8.0.1 \
  && EXECLINE_CHECKSUM=e3c25fa0a40e0206ba60462c1c9abdcb18f6f45d21fa3226bfcf98194da3ffd0 \
  && SKAWARE_RELEASE=2.0.6 \
  && curl -sSf -L https://github.com/just-containers/skaware/releases/download/v${SKAWARE_RELEASE}/s6-${S6_VERSION}-linux-${ARCH}-bin.tar.gz -o /tmp/s6-${S6_VERSION}-linux-${ARCH}-bin.tar.gz \
  && curl -sSf -L https://github.com/just-containers/skaware/releases/download/v${SKAWARE_RELEASE}/execline-${EXECLINE_VERSION}-linux-${ARCH}-bin.tar.gz -o /tmp/execline-${EXECLINE_VERSION}-linux-${ARCH}-bin.tar.gz \
  && printf "%s  %s\n" "${S6_CHECKSUM}" "s6-${S6_VERSION}-linux-${ARCH}-bin.tar.gz" "${EXECLINE_CHECKSUM}" "execline-${EXECLINE_VERSION}-linux-${ARCH}-bin.tar.gz" > /tmp/SHA256SUM \
  && ( cd /tmp; sha256sum -c SHA256SUM; ) \
  && tar -C /usr -zxf /tmp/s6-${S6_VERSION}-linux-${ARCH}-bin.tar.gz \
  && tar -C /usr -zxf /tmp/execline-${EXECLINE_VERSION}-linux-${ARCH}-bin.tar.gz \
  && rm -rf /tmp/* \
  ;

# Configure Postfix / dkim
RUN set -x \
  && postconf -e smtpd_banner="\$myhostname ESMTP" \
  && postconf -Me submission/inet="submission inet n - y - - smtpd" \
  && postconf -Me 2525/inet="2525 inet n - y - - smtpd" \
  && cp --remove-destination /usr/share/postfix/makedefs.out /etc/postfix/makedefs.out \
  && cp -a /var/spool/postfix /var/spool/postfix.cache \
  && rm -f /etc/ssl/private/ssl-cert-snakeoil.key /etc/ssl/certs/ssl-cert-snakeoil.pem \
  && rm -f /etc/opendkim.conf \
  && mkdir /etc/opendkim/ \
  ;

COPY header_checks /etc/postfix/header_checks
COPY opendkim.conf.sh /etc/

COPY s6 /etc/s6/
COPY entry.sh /

ENTRYPOINT ["/entry.sh"]
CMD ["/usr/bin/s6-svscan", "/etc/s6"]
