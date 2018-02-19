###############################################################################
# Dockerfile for image used to run example anyjob deployment.
# Official 'perl' image is used here with addition of all needed modules.
#
# Author:       LightStar
# Created:      19.10.2017
# Last update:  14.12.2017
#

FROM perl:5.26

RUN cpanm JSON::XS
RUN cpanm Redis
RUN cpanm LWP
RUN cpanm LWP::Protocol::https
RUN cpanm MIME::Entity
RUN cpanm Template
RUN cpanm Dancer2
RUN cpanm Dancer2::Plugin::Auth::HTTP::Basic::DWIW
RUN cpanm Dancer2::Plugin::WebSocket
RUN cpanm Twiggy
RUN cpanm CGI::Deurl::XS
RUN cpanm JavaScript::Duktape
RUN cpanm AnyEvent::RipeRedis
RUN cpanm AnyEvent::HTTP

RUN mkdir -p /opt/anyjob
COPY . /opt/anyjob/

ENV ANYJOB_LIB /opt/anyjob/lib
ENV ANYJOB_CONF /opt/anyjob/etc/example/anyjob.cfg

ENTRYPOINT ["perl5.26.0"]
