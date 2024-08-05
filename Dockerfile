##################
# BUILDER - Modules
##################
ARG NGINX_FROM_IMAGE=nginx:1.25.2-alpine
FROM ${NGINX_FROM_IMAGE} as staging

ARG ENABLED_MODULES="headers-more brotli"

SHELL ["/bin/ash", "-exo", "pipefail", "-c"]

RUN if [ "$ENABLED_MODULES" = "" ]; then \
        echo "No additional modules enabled, exiting"; \
        exit 1; \
    fi

COPY ./ /modules/

RUN apk update \
    && apk add linux-headers openssl-dev pcre2-dev zlib-dev openssl abuild \
               musl-dev libxslt libxml2-utils make mercurial gcc unzip git \
               xz g++ coreutils \
    # allow abuild as a root user \
    && printf "#!/bin/sh\\nSETFATTR=true /usr/bin/abuild -F \"\$@\"\\n" > /usr/local/bin/abuild \
    && chmod +x /usr/local/bin/abuild \
    && hg clone -r ${NGINX_VERSION}-${PKG_RELEASE} https://hg.nginx.org/pkg-oss/ \
    && cd pkg-oss \
    && mkdir /tmp/packages \
    && for module in $ENABLED_MODULES; do \
        echo "Building $module for nginx-$NGINX_VERSION"; \
        if [ -d /modules/$module ]; then \
            echo "Building $module from user-supplied sources"; \
            # check if module sources file is there and not empty
            if [ ! -s /modules/$module/source ]; then \
                echo "No source file for $module in modules/$module/source, exiting"; \
                exit 1; \
            fi; \
            # some modules require build dependencies
            if [ -f /modules/$module/build-deps ]; then \
                echo "Installing $module build dependencies"; \
                apk update && apk add $(cat /modules/$module/build-deps | xargs); \
            fi; \
            # if a module has a build dependency that is not in a distro, provide a
            # shell script to fetch/build/install those
            # note that shared libraries produced as a result of this script will
            # not be copied from the staging image to the main one so build static
            if [ -x /modules/$module/prebuild ]; then \
                echo "Running prebuild script for $module"; \
                /modules/$module/prebuild; \
            fi; \
            /pkg-oss/build_module.sh -v $NGINX_VERSION -f -y -o /tmp/packages -n $module $(cat /modules/$module/source); \
            BUILT_MODULES="$BUILT_MODULES $(echo $module | tr '[A-Z]' '[a-z]' | tr -d '[/_\-\.\t ]')"; \
        elif make -C /pkg-oss/alpine list | grep -E "^$module\s+\d+" > /dev/null; then \
            echo "Building $module from pkg-oss sources"; \
            cd /pkg-oss/alpine; \
            make abuild-module-$module BASE_VERSION=$NGINX_VERSION NGINX_VERSION=$NGINX_VERSION; \
            apk add $(. ./abuild-module-$module/APKBUILD; echo $makedepends;); \
            make module-$module BASE_VERSION=$NGINX_VERSION NGINX_VERSION=$NGINX_VERSION; \
            find ~/packages -type f -name "*.apk" -exec mv -v {} /tmp/packages/ \;; \
            BUILT_MODULES="$BUILT_MODULES $module"; \
        else \
            echo "Don't know how to build $module module, exiting"; \
            exit 1; \
        fi; \
    done \
    && echo "BUILT_MODULES=\"$BUILT_MODULES\"" > /tmp/packages/modules.env


###
## ATTENTION HERE
###
FROM ${NGINX_FROM_IMAGE} as builder
RUN --mount=type=bind,target=/tmp/packages/,source=/tmp/packages/,from=staging \
    . /tmp/packages/modules.env \
    && for module in $BUILT_MODULES; do \
           apk add --no-cache --allow-untrusted /tmp/packages/nginx-module-${module}-${NGINX_VERSION}*.apk; \
       done

# RESET SHELL
SHELL ["/bin/sh", "-c"]


###################
# BASE IMAGE
###################
FROM builder as base-image

# Certbot
RUN apk add --update --no-cache certbot certbot-nginx bash openssl

# Caching
RUN mkdir -p /var/cache/nginx

# Folders
RUN mkdir -p /etc/nginx/sites-available
RUN mkdir -p /etc/nginx/sites-enabled
RUN mkdir -p /etc/nginx/sites-templates
RUN mkdir -p /var/www/assets
RUN mkdir -p /var/www/files
RUN mkdir -p /var/www/html

# conf.d folder
COPY conf.d /etc/nginx/conf.d
COPY sites-templates /etc/nginx/sites-templates/

# Assets
COPY assets /var/www/assets

# DHPARAM
RUN openssl dhparam -out /etc/ssl/certs/dhparam-2048.pem 2048

# Certbot and Nginx scripts
COPY scripts.sh ./

###################
# DEV IMAGE
###################
FROM base-image as dev-image

ARG DOLLAR="$"
ARG BACKEND_SERVER_URL=localhost:3000
ARG BACKEND_SERVER_NAME=api.localhost
ARG WEB_SERVER_URL=localhost:3001
ARG WEB_SERVER_NAME=localhost
ARG CMS_SERVER_URL=localhost:3002
ARG CMS_SERVER_NAME=cms.localhost
ARG ASSETS_SERVER_NAME=assets.localhost
ARG FILES_SERVER_NAME=files.localhost

ARG MAX_CONN_API=5
ARG MAX_CONN_WEB=50
ARG MAX_CONN_CMS=50

# SSL
COPY localhost.cert.conf /etc/nginx/
RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/localhost.key -out /etc/ssl/certs/localhost.crt -config /etc/nginx/localhost.cert.conf

# Conf files
COPY nginx.template /etc/nginx/
RUN envsubst < /etc/nginx/nginx.template > /etc/nginx/nginx.conf

RUN envsubst < /etc/nginx/sites-templates/http/api.http.template > /etc/nginx/sites-available/${BACKEND_SERVER_NAME}
RUN envsubst < /etc/nginx/sites-templates/http/cms.http.template > /etc/nginx/sites-available/${CMS_SERVER_NAME}
RUN envsubst < /etc/nginx/sites-templates/http/web.http.template > /etc/nginx/sites-available/${WEB_SERVER_NAME}
RUN envsubst < /etc/nginx/sites-templates/http/assets.http.template > /etc/nginx/sites-available/${ASSETS_SERVER_NAME}
RUN envsubst < /etc/nginx/sites-templates/http/files.http.template > /etc/nginx/sites-available/${FILES_SERVER_NAME}
RUN ln -s /etc/nginx/sites-available/${BACKEND_SERVER_NAME} /etc/nginx/sites-enabled/${BACKEND_SERVER_NAME}
RUN ln -s /etc/nginx/sites-available/${CMS_SERVER_NAME} /etc/nginx/sites-enabled/${CMS_SERVER_NAME}
RUN ln -s /etc/nginx/sites-available/${WEB_SERVER_NAME} /etc/nginx/sites-enabled/${WEB_SERVER_NAME}
RUN ln -s /etc/nginx/sites-available/${ASSETS_SERVER_NAME} /etc/nginx/sites-enabled/${ASSETS_SERVER_NAME}
RUN ln -s /etc/nginx/sites-available/${FILES_SERVER_NAME} /etc/nginx/sites-enabled/${FILES_SERVER_NAME}

EXPOSE 80/TCP
EXPOSE 443/TCP
EXPOSE 443/UDP
CMD ./scripts.sh nginx:https; nginx -g 'daemon off;';

###################
# PREVIEW IMAGE
###################
FROM base-image as preview-image

ARG DOLLAR="$"
ARG BACKEND_SERVER_URL=preview-api:3000
ARG BACKEND_SERVER_NAME=api.localhost
ARG WEB_SERVER_URL=preview-web:3000
ARG WEB_SERVER_NAME=localhost
ARG CMS_SERVER_URL=preview-cms:3000
ARG CMS_SERVER_NAME=cms.localhost
ARG ASSETS_SERVER_NAME=assets.localhost
ARG FILES_SERVER_NAME=files.localhost

ARG MAX_CONN_API=5
ARG MAX_CONN_WEB=50
ARG MAX_CONN_CMS=50

# SSL
COPY localhost.cert.conf /etc/nginx/
RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/localhost.key -out /etc/ssl/certs/localhost.crt -config /etc/nginx/localhost.cert.conf


# Conf files
COPY nginx.template /etc/nginx/
RUN envsubst < /etc/nginx/nginx.template > /etc/nginx/nginx.conf

RUN envsubst < /etc/nginx/sites-templates/http/api.http.template > /etc/nginx/sites-available/${BACKEND_SERVER_NAME}
RUN envsubst < /etc/nginx/sites-templates/http/cms.http.template > /etc/nginx/sites-available/${CMS_SERVER_NAME}
RUN envsubst < /etc/nginx/sites-templates/http/web.http.template > /etc/nginx/sites-available/${WEB_SERVER_NAME}
RUN envsubst < /etc/nginx/sites-templates/http/assets.http.template > /etc/nginx/sites-available/${ASSETS_SERVER_NAME}
RUN envsubst < /etc/nginx/sites-templates/http/files.http.template > /etc/nginx/sites-available/${FILES_SERVER_NAME}
RUN ln -s /etc/nginx/sites-available/${BACKEND_SERVER_NAME} /etc/nginx/sites-enabled/${BACKEND_SERVER_NAME}
RUN ln -s /etc/nginx/sites-available/${CMS_SERVER_NAME} /etc/nginx/sites-enabled/${CMS_SERVER_NAME}
RUN ln -s /etc/nginx/sites-available/${WEB_SERVER_NAME} /etc/nginx/sites-enabled/${WEB_SERVER_NAME}
RUN ln -s /etc/nginx/sites-available/${ASSETS_SERVER_NAME} /etc/nginx/sites-enabled/${ASSETS_SERVER_NAME}
RUN ln -s /etc/nginx/sites-available/${FILES_SERVER_NAME} /etc/nginx/sites-enabled/${FILES_SERVER_NAME}

EXPOSE 80/TCP
EXPOSE 443/TCP
EXPOSE 443/UDP
CMD ./scripts.sh nginx:https; nginx -g 'daemon off;';

###################
# PROD IMAGE
###################
FROM base-image as prod-image

ARG DOLLAR="$"
ARG BACKEND_SERVER_URL=api:3000
ARG BACKEND_SERVER_NAME=api.projetoumportodostodosporum.org
ARG WEB_SERVER_URL=web:3000
ARG WEB_SERVER_NAME=projetoumportodostodosporum.org
ARG CMS_SERVER_URL=cms:3000
ARG CMS_SERVER_NAME=cms.projetoumportodostodosporum.org
ARG ASSETS_SERVER_NAME=assets.projetoumportodostodosporum.org
ARG FILES_SERVER_NAME=files.projetoumportodostodosporum.org

ARG MAX_CONN_API=5
ARG MAX_CONN_WEB=50
ARG MAX_CONN_CMS=50

# Conf files
COPY nginx.template /etc/nginx/
RUN envsubst < /etc/nginx/nginx.template > /etc/nginx/nginx.conf

# Pre Certbot certificate
RUN envsubst < /etc/nginx/sites-templates/https/api.pre.https.template > /etc/nginx/sites-available/pre.${BACKEND_SERVER_NAME}
RUN envsubst < /etc/nginx/sites-templates/https/cms.pre.https.template > /etc/nginx/sites-available/pre.${CMS_SERVER_NAME}
RUN envsubst < /etc/nginx/sites-templates/https/web.pre.https.template > /etc/nginx/sites-available/pre.${WEB_SERVER_NAME}
RUN envsubst < /etc/nginx/sites-templates/https/assets.pre.https.template > /etc/nginx/sites-available/pre.${ASSETS_SERVER_NAME}
RUN envsubst < /etc/nginx/sites-templates/https/files.pre.https.template > /etc/nginx/sites-available/pre.${FILES_SERVER_NAME}
RUN ln -s /etc/nginx/sites-available/pre.${BACKEND_SERVER_NAME} /etc/nginx/sites-enabled/${BACKEND_SERVER_NAME}
RUN ln -s /etc/nginx/sites-available/pre.${WEB_SERVER_NAME} /etc/nginx/sites-enabled/${WEB_SERVER_NAME}
RUN ln -s /etc/nginx/sites-available/pre.${CMS_SERVER_NAME} /etc/nginx/sites-enabled/${CMS_SERVER_NAME}
RUN ln -s /etc/nginx/sites-available/pre.${ASSETS_SERVER_NAME} /etc/nginx/sites-enabled/${ASSETS_SERVER_NAME}
RUN ln -s /etc/nginx/sites-available/pre.${FILES_SERVER_NAME} /etc/nginx/sites-enabled/${FILES_SERVER_NAME}

# Prepare post Cerbot certificate configs
RUN envsubst < /etc/nginx/sites-templates/https/api.https.template > /etc/nginx/sites-available/post.${BACKEND_SERVER_NAME}
RUN envsubst < /etc/nginx/sites-templates/https/cms.https.template > /etc/nginx/sites-available/post.${CMS_SERVER_NAME}
RUN envsubst < /etc/nginx/sites-templates/https/web.https.template > /etc/nginx/sites-available/post.${WEB_SERVER_NAME}
RUN envsubst < /etc/nginx/sites-templates/https/assets.https.template > /etc/nginx/sites-available/post.${ASSETS_SERVER_NAME}
RUN envsubst < /etc/nginx/sites-templates/https/files.https.template > /etc/nginx/sites-available/post.${FILES_SERVER_NAME}

# ADD Certbot cronjob
RUN echo "0 30  *   *   *   /usr/bin/certbot renew --quiet" >> /etc/crontabs/root
RUN crond -l 2 -L /var/log/crond.log

EXPOSE 80/TCP
EXPOSE 443/TCP
EXPOSE 443/UDP
CMD ./scripts.sh nginx:https; nginx -g 'daemon off;';
