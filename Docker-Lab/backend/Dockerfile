FROM node:18

WORKDIR /app

COPY server.js .

RUN npm init -y && npm install express pg cors

CMD ["node", "server.js"]