# syntax=docker/dockerfile:1

# Create a basic stage set up to build APKs
FROM alpine:edge as alpine-builder
RUN apk add \
		--update-cache \
		abuild \
		alpine-conf \
		alpine-sdk \
	&& setup-apkcache /var/cache/apk \
	&& mkdir -p /pkgs/apk \
  && mkdir -p /dist \

	&& echo 'builder ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
RUN adduser -D -G abuild builder && su builder -c 'abuild-keygen -a -n'

# This stage builds an APK from the dist tarball
FROM alpine-builder as alpine-apk-builder

ARG VERSION
ARG PATCH

RUN find /pkgs/apk -type f -name APKINDEX.tar.gz -delete \
   && chown -R builder /dist /pkgs

COPY alpine/* /dist/

USER builder
RUN cd /dist \
	&& abuild checksum \
	&& abuild -rv -P /pkgs/apk # 2>&1 > log.log #

# This isolated stage builds YARSS2 in a lscr.io/linuxserver/deluge container
FROM lscr.io/linuxserver/deluge:latest as plugin_builder

RUN \
  mkdir -p /plugins \
  cd /tmp \
  && git clone https://bitbucket.org/bendikro/deluge-yarss-plugin.git	\
  && python3 setup.py bdist_egg \
  && cp dist/*.egg /plugins/ \
