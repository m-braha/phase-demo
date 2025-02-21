FROM node:18-slim

# Install Phase CLI
RUN apt-get update && apt-get install -y curl && \
    curl -fsSL https://pkg.phase.dev/install.sh | bash && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy package files
COPY package*.json ./
RUN npm install

# Copy application code
COPY src/ ./src/

# Copy and set up entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENV PHASE_HOST=https://phase.aops.tools
ENV PHASE_APP=example-app

EXPOSE 3000

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["node", "src/app.js"]
