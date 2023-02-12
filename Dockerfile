FROM nginx
LABEL maintainer Sean.li
RUN rm -rf /usr/share/nginx/html/*
ADD htdocs/* /usr/share/nginx/html/