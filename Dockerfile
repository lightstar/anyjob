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

RUN mkdir -p /opt/anyjob
COPY . /opt/anyjob/

ENV ANYJOB_LIB /opt/anyjob/lib
ENV ANYJOB_CONF /opt/anyjob/etc/docker/anyjob.cfg

ENTRYPOINT ["perl5.26.0"]
