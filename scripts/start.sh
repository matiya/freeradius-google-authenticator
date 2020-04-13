#!/bin/sh
if [ "${RADIUS_DEBUG}" = "yes" ]
  then
    /wait-for.sh ${API_HOST}:${API_PORT} -t 55 -- freeradius -X -d /etc/freeradius/3.0
  else
    /wait-for.sh ${API_HOST}:${API_PORT} -t 55 -- freeradius -d /etc/freeradius/3.0
fi
