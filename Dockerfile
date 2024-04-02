FROM debian:9.2

# Adjusting the sources.list to use an archived source and stable-security updates
RUN sed -i 's/deb.debian.org/archive.debian.org/g' /etc/apt/sources.list && \
    sed -i 's/security.debian.org/debian-security.archive.debian.org/g' /etc/apt/sources.list && \
    sed -i 's/stable\/updates/stable-security\/updates/' /etc/apt/sources.list

# Pre-accepting the Oracle license for Java installation if needed and other preseeding
RUN echo mariadb-server mysql-server/root_password password vulnerables | debconf-set-selections && \
    echo mariadb-server mysql-server/root_password_again password vulnerables | debconf-set-selections

# Installing software
RUN apt-get update && \
    apt-get upgrade -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    apache2 \
    mariadb-server \
    php \
    php-mysql \
    php-pgsql \
    php-pear \
    php-gd \
    modsecurity-crs \
    curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY php.ini /etc/php5/apache2/php.ini
COPY dvwa /var/www/html
COPY config.inc.php /var/www/html/config/

# Adjust file permissions
RUN chown www-data:www-data -R /var/www/html && \
    rm /var/www/html/index.html

# Start services and configure MySQL
# Note: Using `service` command might not work as expected in Docker
RUN service mysql start && \
    sleep 3 && \
    mysql -uroot -pvulnerables -e "CREATE USER 'app'@'localhost' IDENTIFIED BY 'vulnerables'; CREATE DATABASE dvwa; GRANT ALL privileges ON dvwa.* TO 'app'@'localhost'; FLUSH PRIVILEGES;"

# Configure Apache and ModSecurity
RUN a2enmod security2
RUN sed -i 's/SecRuleEngine DetectionOnly/SecRuleEngine On/' /etc/modsecurity/modsecurity.conf

# Custom ModSecurity rules
RUN mkdir -p /etc/modsecurity/custom && \
    curl https://pastebin.com/raw/3QJdaDvG > /etc/modsecurity/custom/rules.conf && \
    echo "IncludeOptional /etc/modsecurity/custom/*.conf" >> /etc/apache2/mods-available/security2.conf

# Fix Apache server name warning
RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf

EXPOSE 80

COPY main.sh /
ENTRYPOINT ["/main.sh"]
