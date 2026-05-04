FROM php:8.3-fpm-alpine

# Install system dependencies
RUN apk add --no-cache \
    build-base \
    curl \
    libpng-dev \
    libjpeg-turbo-dev \
    libwebp-dev \
    zlib-dev \
    libzip-dev \
    zip \
    unzip \
    git \
    bash \
    imagemagick-dev \
    postgresql-client \
    mysql-client \
    oniguruma-dev \
    openssl \
    supervisor

# Install PHP extensions
RUN docker-php-ext-configure gd --with-jpeg --with-webp \
    && docker-php-ext-install -j$(nproc) \
        gd \
        pdo_mysql \
        zip \
        bcmath \
        exif \
        pcntl \
        intl \
        opcache

# Install PECL extensions
RUN pecl install imagick redis mongodb \
    && docker-php-ext-enable imagick redis mongodb

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Install Node.js and npm
RUN apk add --no-cache nodejs npm

# Set working directory
WORKDIR /var/www/html

# Copy application files
COPY . .

# Install PHP dependencies
RUN composer install --no-interaction --optimize-autoloader

# Install Node dependencies and build frontend
RUN npm ci && npm run build

# Create necessary directories and set permissions
RUN mkdir -p \
    storage/logs \
    storage/app/public \
    storage/framework/cache \
    storage/framework/sessions \
    storage/framework/views \
    bootstrap/cache \
    && chown -R www-data:www-data storage bootstrap \
    && chmod -R 755 storage bootstrap

# Copy supervisor configuration
RUN mkdir -p /etc/supervisor/conf.d
COPY docker/supervisor/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Copy PHP configuration
COPY docker/php/php.ini /usr/local/etc/php/php.ini
COPY docker/php/www.conf /usr/local/etc/php-fpm.d/www.conf

# Expose port
EXPOSE 9000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:9000/health || exit 1

CMD ["php-fpm"]
