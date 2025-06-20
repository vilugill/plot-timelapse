# Multi-architecture build for Raspberry Pi support
# Stage 1: Build stage
FROM --platform=$TARGETPLATFORM nginx:alpine AS build

# Set up build arguments for multi-architecture support
ARG TARGETPLATFORM
ARG BUILDPLATFORM
RUN echo "I am running on $BUILDPLATFORM, building for $TARGETPLATFORM"

# Create directory structure
RUN mkdir -p /usr/share/nginx/html/photos

# Stage 2: Final image
FROM --platform=$TARGETPLATFORM nginx:alpine

# Copy application files from build stage
COPY --from=build /usr/share/nginx/html /usr/share/nginx/html

# Copy web files
COPY src/ /usr/share/nginx/html/

# Copy nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Set permissions for photo directory to allow uploads
RUN chmod -R 755 /usr/share/nginx/html/photos && \
    # Create cache directories with proper permissions
    mkdir -p /var/cache/nginx && \
    chmod -R 755 /var/cache/nginx && \
    # Ensure nginx user owns the web directories
    chown -R nginx:nginx /usr/share/nginx/html && \
    # Verify nginx config
    nginx -t

# Expose port
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost/ || exit 1

# Add labels for better container management
LABEL maintainer="Photo Gallery Maintainer" \
      description="Responsive Photo Gallery for daily photos" \
      version="1.0"

# Set up entrypoint
CMD ["nginx", "-g", "daemon off;"]
