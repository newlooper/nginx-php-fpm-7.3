FROM ubuntu:18.04

MAINTAINER Dylan <newlooper@hotmail.com>

#############################################################################################
# Locale, Language, Timezone
ENV OS_LOCALE="en_US.UTF-8"
RUN DEBIAN_FRONTEND=noninteractive \
	apt-get update \
	&& apt-get install -y locales tzdata \
	&& locale-gen ${OS_LOCALE} \
	&& ln -fs /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
	&& dpkg-reconfigure -f noninteractive tzdata
ENV LANG=${OS_LOCALE} \
	LC_ALL=${OS_LOCALE} \
	LANGUAGE=en_US:en

#############################################################################################
# App Env
ENV php_conf /etc/php/7.3/fpm/php.ini
ENV fpm_conf /etc/php/7.3/fpm/pool.d/www.conf
ENV COMPOSER_VERSION 1.9.0

#############################################################################################
# Install Basic Requirements
RUN DEBIAN_FRONTEND=noninteractive \
	buildDeps='software-properties-common' \
	&& apt-get install --no-install-recommends --no-install-suggests -y $buildDeps \
	&& add-apt-repository -y ppa:ondrej/php \
	&& add-apt-repository -y ppa:nginx/stable \
	&& apt-get update \
	&& apt-get install --no-install-recommends --no-install-suggests -q -y \
		gcc make autoconf libc-dev pkg-config libmcrypt-dev php-pear \
		cron \
		iputils-ping \
		net-tools \
		curl \
		wget \
		vim \
		zip \
		unzip \
		python-pip \
		python-setuptools \
		nginx \
		php7.3-bcmath \
		php7.3-bz2 \
		php7.3-fpm \
		php7.3-cli \
		php7.3-dev \
		php7.3-common \
		php7.3-json \
		php7.3-opcache \
		php7.3-readline \
		php7.3-mbstring \
		php7.3-curl \
		php7.3-memcached \
		php7.3-imagick \
		php7.3-mysql \
		php7.3-zip \
		php7.3-pgsql \
		php7.3-intl \
		php7.3-xml \
		php7.3-redis \
		php7.3-gd \
		php-mongodb \
	&& mkdir -p /run/php \
	&& pip install wheel \
	&& pip install supervisor supervisor-stdout \
	&& echo "#!/bin/sh\nexit 0" > /usr/sbin/policy-rc.d \
	&& sed -i -e "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" ${php_conf} \
	&& sed -i -e "s/memory_limit\s*=\s*.*/memory_limit = 256M/g" ${php_conf} \
	&& sed -i -e "s/upload_max_filesize\s*=\s*2M/upload_max_filesize = 100M/g" ${php_conf} \
	&& sed -i -e "s/post_max_size\s*=\s*8M/post_max_size = 100M/g" ${php_conf} \
	&& sed -i -e "s/variables_order = \"GPCS\"/variables_order = \"EGPCS\"/g" ${php_conf} \
	&& sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" /etc/php/7.3/fpm/php-fpm.conf \
	&& sed -i -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" ${fpm_conf} \
	&& sed -i -e "s/pm.max_children = 5/pm.max_children = 4/g" ${fpm_conf} \
	&& sed -i -e "s/pm.start_servers = 2/pm.start_servers = 3/g" ${fpm_conf} \
	&& sed -i -e "s/pm.min_spare_servers = 1/pm.min_spare_servers = 2/g" ${fpm_conf} \
	&& sed -i -e "s/pm.max_spare_servers = 3/pm.max_spare_servers = 4/g" ${fpm_conf} \
	&& sed -i -e "s/pm.max_requests = 500/pm.max_requests = 200/g" ${fpm_conf} \
	&& sed -i -e "s/^;clear_env = no$/clear_env = no/" ${fpm_conf}

RUN yes '' | pecl install -f mcrypt-1.0.2 \
	&& echo "extension=mcrypt.so" > /etc/php/7.3/cli/conf.d/mcrypt.ini \
	&& echo "extension=mcrypt.so" > /etc/php/7.3/fpm/conf.d/mcrypt.ini

# Clean
RUN apt-get purge -y --auto-remove $buildDeps \
	&& apt-get autoremove -y \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/*

RUN curl -o /tmp/composer-setup.php https://getcomposer.org/installer \
	&& curl -o /tmp/composer-setup.sig https://composer.github.io/installer.sig \
	&& php -r "if (hash('SHA384', file_get_contents('/tmp/composer-setup.php')) !== trim(file_get_contents('/tmp/composer-setup.sig'))) { unlink('/tmp/composer-setup.php'); echo 'Invalid installer' . PHP_EOL; exit(1); }" \
	&& php /tmp/composer-setup.php --no-ansi --install-dir=/usr/local/bin --filename=composer --version=${COMPOSER_VERSION} \
	&& rm -rf /tmp/composer-setup.php

# Nginx Upstream config
ADD ./conf/upstream.conf /etc/nginx/upstream.conf

# Add upstream config to nginx.conf
COPY ./conf/nginx.conf /etc/nginx/nginx.conf

# Supervisor config
ADD ./conf/supervisord.conf /etc/supervisord.conf

# Override default nginx welcome page
COPY html /usr/share/nginx/html

# Add Scripts
ADD ./start.sh /start.sh

EXPOSE 80 443

CMD ["/start.sh"]
