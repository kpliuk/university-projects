FROM nginx:1.27-alpine

COPY index.html /usr/share/nginx/html/index.html
COPY nginx.conf /etc/nginx/conf.d/default.conf

ARG API_BASE_URL=/api
RUN sed -i "s|__API_BASE_URL__|${API_BASE_URL}|g" /usr/share/nginx/html/index.html

EXPOSE 80
