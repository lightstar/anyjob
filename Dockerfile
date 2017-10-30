FROM perl:5.26

RUN cpanm JSON::XS
RUN cpanm Redis
RUN cpanm LWP
RUN cpanm LWP::Protocol::https
RUN cpanm MIME::Entity
RUN cpanm Template
RUN cpanm Dancer2

RUN mkdir -p /opt/anyjob
COPY . /opt/anyjob/

ENV ANYJOB_LIB /opt/anyjob/lib
ENV ANYJOB_CONF /opt/anyjob/etc/anyjob.cfg

ENTRYPOINT ["perl5.26.0"]
