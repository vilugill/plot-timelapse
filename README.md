# Daily Photo Gallery

A simple responsive website that displays daily photos in a gallery format. This application is designed to run on a Raspberry Pi 4B using Docker but can also be tested locally.

## Features

- Displays the latest photo prominently on the homepage
- Gallery view for browsing through all previous photos
- Automatic detection of new photos (based on YYYY-MM-DD filename format)
- Responsive design for all screen sizes
- Lightweight implementation using vanilla JavaScript (no frameworks)

## Quick Start

### Testing Locally

1. Run the included start script:

```powershell
.\start_server.ps1
```

This will start a local web server and open the gallery in your browser.

### Building and Deploying to Raspberry Pi

#### Easy Method (Recommended)

1. Run the Docker build script:

```powershell
.\docker-build.ps1
```

This script will:
- Check for Docker and Docker BuildX
- Build for multiple architectures (amd64 and arm/v7)
- Optionally push to Docker Hub
- Provide commands for deployment

#### Manual Method

1. Set up Docker BuildX:

```powershell
docker buildx create --name mybuilder --use
```

2. Build the Docker image for ARM architecture:

```powershell
docker buildx build --platform linux/arm/v7 -t yourusername/photo-gallery:latest --push .
```

3. On your Raspberry Pi, pull and run the image:

```bash
docker pull yourusername/photo-gallery:latest
docker run -d -p 80:80 -v /path/to/photos:/usr/share/nginx/html/photos yourusername/photo-gallery:latest
```

## Photo Requirements

- Photos should be named with the format: `YYYY-MM-DD-description.jpg` (e.g., `2025-06-20-sunset.jpg`)
- Supported formats: JPG, JPEG, PNG
- Photos will be automatically sorted by date (newest first)

## Directory Structure

```
photo-gallery/
â”œâ”€â”€ src/               # Web application files
â”‚   â”œâ”€â”€ index.html     # Main HTML file
â”‚   â”œâ”€â”€ styles.css     # CSS styles
â”‚   â”œâ”€â”€ script.js      # JavaScript code
â”‚   â””â”€â”€ photos/        # Directory for photos
â”‚       â””â”€â”€ YYYY-MM-DD-*.jpg
â”œâ”€â”€ Dockerfile         # Docker configuration
â”œâ”€â”€ start_server.ps1   # Script to start local server
â””â”€â”€ README.md          # This documentation
```

## Customization

- Edit `src/styles.css` to change the appearance
- Modify `src/index.html` to add additional content
- Update `src/script.js` to change behavior or add features

## Troubleshooting

- If no photos appear, check that your photos are correctly named with the YYYY-MM-DD format
- For permission issues on Raspberry Pi: `chmod -R 755 /path/to/photos`
