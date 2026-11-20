FROM kathara/base

RUN apt-get update && \
    apt-get install -y --no-install-recommends nginx && \
    rm -rf /var/lib/apt/lists/* && \
    rm -f /etc/nginx/sites-enabled/default

COPY site/ /var/www/jglh/
COPY nginx/jglh.conf /etc/nginx/sites-available/jglh.conf

RUN ln -sf /etc/nginx/sites-available/jglh.conf /etc/nginx/sites-enabled/jglh.conf && \
    nginx -t
