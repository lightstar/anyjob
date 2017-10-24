FROM perl:5.26

RUN cpanm JSON::XS
RUN cpanm Redis
RUN cpanm MIME::Entity
RUN cpanm Template

RUN mkdir -p /opt/anyjob
COPY . /opt/anyjob/

ENV ANYJOB_LIB /opt/anyjob/lib
ENV ANYJOB_CONF /opt/anyjob/etc/anyjob.cfg

ENTRYPOINT ["perl5.26.0"]
