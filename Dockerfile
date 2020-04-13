FROM ubuntu:rolling

RUN apt-get update -y && apt-get -y install

RUN ln -fs /usr/share/zoneinfo/America/Santiago /etc/localtime
RUN apt-get install libpam-google-authenticator freeradius-postgresql freeradius-rest freeradius-common netcat -qy

ADD --chown=root:root ./raddb/ /etc/freeradius/3.0
RUN ln -sf /etc/freeradius/3.0/mods-available/sql /etc/freeradius/3.0/mods-enabled/sql

# Edit /etc/pam.d/radiusd file
RUN sed -i "s/^@\(.*\)/#@\1/g" /etc/pam.d/radiusd
RUN echo "auth requisite pam_google_authenticator.so forward_pass" >> /etc/pam.d/radiusd
RUN echo "auth required pam_unix.so use_first_pass" >> /etc/pam.d/radiusd
# Copy existing /etc/freeradius/sites-available/default file to container
RUN sed -i "s/^#\(.*pam\)/\1/g" /etc/freeradius/3.0/sites-available/default
RUN echo "DEFAULT Auth-Type := PAM" >> /etc/freeradius/3.0/users
RUN sed -i "s/^\([user|group].*\=.*\)freerad/\1root/g" /etc/freeradius/3.0/radiusd.conf
# Edit /etc/freeradius/3.0/mods-config/files/authorize file
RUN sed -i '1s/^/# Instruct FreeRADIUS to use PAM to authenticate users\n/' /etc/freeradius/3.0/mods-config/files/authorize
RUN sed -i '2s/^/DEFAULT Auth-Type := PAM\n/' /etc/freeradius/3.0/mods-config/files/authorize
# Create symbolic link
RUN ln -s /etc/freeradius/3.0/mods-available/pam /etc/freeradius/3.0/mods-enabled/pam

EXPOSE 1812/udp 1813/udp
ENV DB_HOST=postgres \
    DB_PORT=5432 \
    DB_USER=debug \
    DB_PASS=debug \
    DB_NAME=radius \
    API_HOST=django \
    API_PORT=8000 \
    API_PROTOCOL=http \
    API_TOKEN=djangofreeradiusapitoken \
    RADIUS_SSL_MODE=disable \
    RADIUS_KEY=testing123 \
    RADIUS_CLIENTS=10.0.0.0/24 \
    RADIUS_DEBUG=no

ADD ./scripts/start.sh /start.sh
ADD ./scripts/wait-for.sh /wait-for.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]
