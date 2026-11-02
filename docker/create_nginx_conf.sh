#!/bin/sh
# substitude the key value in the nginx config file
# could use gettext/envsubst but sed is more ubiquitous and simple enough here
sed "s|\${LITELLM_MASTER_KEY}|${LITELLM_MASTER_KEY}|g" /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf
# the final nginx.conf contains the master key, so it must not be printed to the container logs