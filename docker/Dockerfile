# take a stable image from https://github.com/BerriAI/litellm/pkgs/container/litellm-database/versions
# keep previously used version until the upgrade is fully validated
#FROM ghcr.io/berriai/litellm-database:main-v1.81.0-stable
FROM ghcr.io/berriai/litellm-database:v1.103.3


ARG IMAGE_TAG=latest
ENV IMAGE_TAG=$IMAGE_TAG

# Env varialble for litellm
ENV LITELLM_MASTER_KEY="sk-default"

# Install nginx
RUN apk update \
 && apk add --no-cache nginx jq aws-cli

RUN adduser -D -g 'nginx' nginx

# Copy nginx config template
COPY nginx.conf.template /etc/nginx/nginx.conf.template

COPY create_nginx_conf.sh /app/create_nginx_conf.sh
RUN chmod +x /app/create_nginx_conf.sh

#COPY ./hook.py /etc/litellm/hook.py
#COPY config.yaml /etc/litellm/config.yaml
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh




# Expose proxy port
EXPOSE 4001
EXPOSE 4000

WORKDIR /app

ENV PYTHONPATH="/etc/litellm:$PYTHONPATH"

# Start both the original service and nginx
#
LABEL org.opencontainers.image.revision=$IMAGE_TAG

ENTRYPOINT ["./entrypoint.sh"]
