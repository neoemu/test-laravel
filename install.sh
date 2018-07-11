#!/bin/sh
yum install -y docker
service docker start
chkonfig docker on
cat <<EOF > /opt/Dockerfile
FROM centos:latest

RUN yum install -y epel-release; \
    rpm -Uvh https://mirror.webtatic.com/yum/el7/webtatic-release.rpm; \
    yum repolist; \
    yum install -y php71w php71w-common php71w-gd php71w-phar php71w-xml php71w-cli php71w-mbstring php71w-tokenizer php71w-openssl php71w-pdo; \
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"; \
    php composer-setup.php; \
    cp composer.phar /usr/bin/composer; \
    rm -f composer.phar composer-setup.php; \
    composer create-project laravel/laravel laravel; \
    composer require predis/predis; \
    sed -i "s/"REDIS_HOST=127.0.0.1"/"REDIS_HOST=laravel-redis"/g" /laravel/.env

RUN echo "#!/bin/bash" >> start.sh; \
    echo "cd /laravel" >> start.sh; \
    echo "php artisan serve --host=0.0.0.0 --port=8080" >> start.sh

RUN chmod +x start.sh

ENTRYPOINT ["/start.sh"]
EOF
cd /opt
docker build -t laravel .
mkdir -p /redis-data
docker run -d --name laravel-redis -p 6379:6379 -v /redis-data:/data redis
docker run -it -d --name laravel-web --link laravel-redis:redis -p 80:8080 laravel
