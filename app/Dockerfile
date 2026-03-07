# ─────────────────────────────────────────────
# Stage 1: Build the React app
# ─────────────────────────────────────────────
FROM node:18-alpine AS builder

WORKDIR /app

# Copy dependency files first (layer caching)
COPY package*.json ./
RUN npm ci --production=false

# Pass build number from Jenkins into the React build
ARG BUILD_NUMBER=local
ENV REACT_APP_BUILD_NUMBER=$BUILD_NUMBER

# Copy source and build
COPY . .
RUN npm run build

# ─────────────────────────────────────────────
# Stage 2: Serve with lightweight Nginx
# ─────────────────────────────────────────────
FROM nginx:1.25-alpine

# Remove default nginx config
RUN rm /etc/nginx/conf.d/default.conf

# Copy custom nginx config
COPY nginx.conf /etc/nginx/conf.d/

# Copy built React app from builder stage
COPY --from=builder /app/build /usr/share/nginx/html

# Health check for load balancers / ECS
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:80/ || exit 1

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
