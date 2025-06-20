#!/bin/bash

# Daily Photo Gallery Setup Script
echo -e "\e[1;36mSetting up Daily Photo Gallery...\e[0m"

# Create directory structure
echo -e "\e[0;33mCreating directory structure...\e[0m"
mkdir -p src/photos

# Create index.html
echo -e "\e[0;33mCreating index.html...\e[0m"
cat > src/index.html << 'EOL'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Daily Photo Gallery</title>
    <link rel="stylesheet" href="styles.css">
</head>
<body>
    <header>
        <h1>Daily Photo Gallery</h1>
        <nav>
            <ul>
                <li><a href="#" class="active" data-view="latest">Latest Photo</a></li>
                <li><a href="#" data-view="gallery">Browse Gallery</a></li>
            </ul>
        </nav>
    </header>
    
    <main>
        <div id="latest-view" class="view active">
            <div class="photo-container">
                <img id="latest-photo" src="" alt="Latest photo">
                <div class="photo-info">
                    <h2 id="latest-photo-date"></h2>
                    <p id="latest-photo-time"></p>
                </div>
            </div>
        </div>
        
        <div id="gallery-view" class="view">
            <div class="controls">
                <button id="prev-page">&laquo; Previous</button>
                <span id="page-info">Page 1 of 1</span>
                <button id="next-page">Next &raquo;</button>
            </div>
            
            <div class="gallery-grid" id="gallery-grid">
                <!-- Photos will be dynamically inserted here -->
            </div>
            
            <div class="photo-preview" id="photo-preview">
                <img id="preview-image" src="" alt="Selected photo">
                <div class="photo-info">
                    <h2 id="preview-date"></h2>
                    <p id="preview-time"></p>
                </div>
            </div>
        </div>
    </main>
    
    <footer>
        <p>Daily Photo Gallery | Auto-refreshes every 5 minutes</p>
    </footer>
    
    <script src="script.js"></script>
</body>
</html>
EOL

# Create styles.css
echo -e "\e[0;33mCreating styles.css...\e[0m"
cat > src/styles.css << 'EOL'
/* Base styles */
* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, 'Open Sans', 'Helvetica Neue', sans-serif;
    line-height: 1.6;
    color: #333;
    background-color: #f5f5f5;
    max-width: 1200px;
    margin: 0 auto;
    padding: 20px;
}

/* Header */
header {
    background-color: #fff;
    padding: 20px;
    border-radius: 8px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    margin-bottom: 20px;
}

h1 {
    color: #2c3e50;
    margin-bottom: 15px;
    text-align: center;
}

nav ul {
    display: flex;
    list-style: none;
    justify-content: center;
    gap: 20px;
}

nav a {
    text-decoration: none;
    color: #7f8c8d;
    font-weight: 500;
    padding: 5px 10px;
    border-radius: 4px;
    transition: all 0.3s;
}

nav a.active {
    color: #2980b9;
    background-color: #ecf0f1;
}

nav a:hover {
    background-color: #ecf0f1;
}

/* Main content */
main {
    background-color: #fff;
    padding: 20px;
    border-radius: 8px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    min-height: 500px;
}

.view {
    display: none;
}

.view.active {
    display: block;
}

/* Latest photo view */
.photo-container {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 15px;
}

.photo-container img {
    max-width: 100%;
    max-height: 70vh;
    border-radius: 4px;
    box-shadow: 0 4px 8px rgba(0,0,0,0.2);
}

.photo-info {
    text-align: center;
    padding: 10px;
    background-color: #f8f9fa;
    border-radius: 4px;
    width: 100%;
    max-width: 500px;
}

.photo-info h2 {
    color: #2c3e50;
    margin-bottom: 5px;
}

/* Gallery view */
.controls {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 20px;
}

.controls button {
    background-color: #3498db;
    color: white;
    border: none;
    padding: 8px 15px;
    border-radius: 4px;
    cursor: pointer;
    transition: background-color 0.3s;
}

.controls button:hover {
    background-color: #2980b9;
}

.controls button:disabled {
    background-color: #bdc3c7;
    cursor: not-allowed;
}

.gallery-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
    gap: 15px;
    margin-bottom: 20px;
}

.gallery-grid img {
    width: 100%;
    height: 150px;
    object-fit: cover;
    border-radius: 4px;
    cursor: pointer;
    transition: transform 0.2s;
}

.gallery-grid img:hover {
    transform: scale(1.05);
}

.photo-preview {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 15px;
    margin-top: 30px;
}

.photo-preview img {
    max-width: 100%;
    max-height: 50vh;
    border-radius: 4px;
    box-shadow: 0 4px 8px rgba(0,0,0,0.2);
}

/* Highlight new photos */
.new-photo {
    position: relative;
}

.new-photo::after {
    content: 'NEW';
    position: absolute;
    top: -10px;
    right: -10px;
    background-color: #e74c3c;
    color: white;
    font-size: 0.7em;
    padding: 3px 6px;
    border-radius: 10px;
    animation: pulse 1.5s infinite;
}

@keyframes pulse {
    0% { transform: scale(1); }
    50% { transform: scale(1.1); }
    100% { transform: scale(1); }
}

/* Footer */
footer {
    text-align: center;
    margin-top: 20px;
    color: #7f8c8d;
    font-size: 0.9em;
}

/* Responsive adjustments */
@media (max-width: 768px) {
    body {
        padding: 10px;
    }
    
    header, main {
        padding: 15px;
    }
    
    .gallery-grid {
        grid-template-columns: repeat(auto-fill, minmax(120px, 1fr));
    }
    
    .gallery-grid img {
        height: 120px;
    }
}

@media (max-width: 480px) {
    nav ul {
        flex-direction: column;
        gap: 10px;
        align-items: center;
    }
    
    .gallery-grid {
        grid-template-columns: repeat(auto-fill, minmax(100px, 1fr));
    }
    
    .gallery-grid img {
        height: 100px;
    }
}
EOL

# Create script.js
echo -e "\e[0;33mCreating script.js...\e[0m"
cat > src/script.js << 'EOL'
document.addEventListener('DOMContentLoaded', function() {
    // DOM elements
    const navLinks = document.querySelectorAll('nav a');
    const views = document.querySelectorAll('.view');
    const latestPhoto = document.getElementById('latest-photo');
    const latestPhotoDate = document.getElementById('latest-photo-date');
    const latestPhotoTime = document.getElementById('latest-photo-time');
    const galleryGrid = document.getElementById('gallery-grid');
    const previewImage = document.getElementById('preview-image');
    const previewDate = document.getElementById('preview-date');
    const previewTime = document.getElementById('preview-time');
    const prevPageBtn = document.getElementById('prev-page');
    const nextPageBtn = document.getElementById('next-page');
    const pageInfo = document.getElementById('page-info');
    
    // Application state
    let photos = [];
    let currentPage = 0;
    let photosPerPage = 12;
    
    // Switch between views
    navLinks.forEach(link => {
        link.addEventListener('click', function(e) {
            e.preventDefault();
            
            // Update active tab
            navLinks.forEach(l => l.classList.remove('active'));
            this.classList.add('active');
            
            // Show selected view
            const targetView = this.getAttribute('data-view');
            views.forEach(view => {
                view.classList.remove('active');
                if (view.id === `${targetView}-view`) {
                    view.classList.add('active');
                }
            });
        });
    });
    
    // Format date for display
    function formatDate(dateStr) {
        const date = new Date(dateStr);
        return {
            date: date.toLocaleDateString('en-US', { 
                weekday: 'long', 
                year: 'numeric', 
                month: 'long', 
                day: 'numeric' 
            }),
            time: date.toLocaleTimeString('en-US', {
                hour: '2-digit',
                minute: '2-digit'
            })
        };
    }
    
    // Load photos
    async function loadPhotos() {
        try {
            const response = await fetch('photos/');
            if (!response.ok) {
                throw new Error('Failed to load photos directory');
            }
            
            const html = await response.text();
            const parser = new DOMParser();
            const doc = parser.parseFromString(html, 'text/html');
            
            // Extract all JPG links
            const links = Array.from(doc.querySelectorAll('a'))
                .filter(a => a.href.endsWith('.jpg'));
            
            // Process each photo link
            photos = links.map(link => {
                const fileName = link.textContent.trim();
                // Extract date from filename (expected format: YYYY-MM-DD_HH-MM-SS.jpg)
                const dateMatch = fileName.match(/(\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2})\.jpg$/);
                
                if (dateMatch) {
                    const dateStr = dateMatch[1].replace('_', 'T').replace(/-/g, ':');
                    const isoDate = `${dateStr.slice(0, 10)}T${dateStr.slice(11)}`;
                    return {
                        url: `photos/${fileName}`,
                        date: new Date(isoDate),
                        fileName: fileName
                    };
                }
                
                return null;
            }).filter(photo => photo !== null);
            
            // Sort photos by date (newest first)
            photos.sort((a, b) => b.date - a.date);
            
            // Display photos
            displayLatestPhoto();
            displayGallery();
            
        } catch (error) {
            console.error('Error loading photos:', error);
            
            // Fall back to sample data if there's an error
            displaySampleData();
        }
    }
    
    // Display sample data if loading fails
    function displaySampleData() {
        // Create sample photos with the current date
        const now = new Date();
        
        // Generate 5 sample photos with different times
        photos = Array.from({ length: 5 }, (_, i) => {
            const photoDate = new Date(now);
            photoDate.setHours(now.getHours() - i);
            
            return {
                url: `photos/sample${i+1}.jpg`,
                date: photoDate,
                fileName: `sample${i+1}.jpg`
            };
        });
        
        // Display the sample photos
        displayLatestPhoto();
        displayGallery();
    }
    
    // Display latest photo
    function displayLatestPhoto() {
        if (photos.length > 0) {
            const latest = photos[0];
            latestPhoto.src = latest.url;
            latestPhoto.alt = latest.fileName;
            
            const formattedDate = formatDate(latest.date);
            latestPhotoDate.textContent = formattedDate.date;
            latestPhotoTime.textContent = formattedDate.time;
        } else {
            latestPhoto.src = '';
            latestPhotoDate.textContent = 'No photos available';
            latestPhotoTime.textContent = '';
        }
    }
    
    // Display gallery
    function displayGallery() {
        // Update pagination
        const totalPages = Math.ceil(photos.length / photosPerPage);
        updatePagination(totalPages);
        
        // Clear gallery
        galleryGrid.innerHTML = '';
        
        // Calculate which photos to show on current page
        const startIndex = currentPage * photosPerPage;
        const endIndex = Math.min(startIndex + photosPerPage, photos.length);
        const currentPhotos = photos.slice(startIndex, endIndex);
        
        // Get date 24 hours ago to highlight new photos
        const oneDayAgo = new Date();
        oneDayAgo.setDate(oneDayAgo.getDate() - 1);
        
        // Add photos to gallery
        currentPhotos.forEach(photo => {
            const img = document.createElement('img');
            img.src = photo.url;
            img.alt = photo.fileName;
            
            // Highlight photos less than 24 hours old
            if (photo.date > oneDayAgo) {
                img.classList.add('new-photo');
            }
            
            // Add click event to view photo
            img.addEventListener('click', () => {
                previewImage.src = photo.url;
                previewImage.alt = photo.fileName;
                
                const formattedDate = formatDate(photo.date);
                previewDate.textContent = formattedDate.date;
                previewTime.textContent = formattedDate.time;
                
                // Scroll to preview
                document.getElementById('photo-preview').scrollIntoView({ behavior: 'smooth' });
            });
            
            galleryGrid.appendChild(img);
        });
        
        // Select first image in gallery for preview
        if (currentPhotos.length > 0) {
            previewImage.src = currentPhotos[0].url;
            previewImage.alt = currentPhotos[0].fileName;
            
            const formattedDate = formatDate(currentPhotos[0].date);
            previewDate.textContent = formattedDate.date;
            previewTime.textContent = formattedDate.time;
        } else {
            previewImage.src = '';
            previewDate.textContent = 'No photos available';
            previewTime.textContent = '';
        }
    }
    
    // Update pagination controls
    function updatePagination(totalPages) {
        pageInfo.textContent = `Page ${currentPage + 1} of ${totalPages || 1}`;
        
        // Update button states
        prevPageBtn.disabled = currentPage === 0;
        nextPageBtn.disabled = currentPage >= totalPages - 1 || totalPages === 0;
    }
    
    // Pagination event handlers
    prevPageBtn.addEventListener('click', () => {
        if (currentPage > 0) {
            currentPage--;
            displayGallery();
            // Scroll to top of gallery
            galleryGrid.scrollIntoView({ behavior: 'smooth' });
        }
    });
    
    nextPageBtn.addEventListener('click', () => {
        const totalPages = Math.ceil(photos.length / photosPerPage);
        if (currentPage < totalPages - 1) {
            currentPage++;
            displayGallery();
            // Scroll to top of gallery
            galleryGrid.scrollIntoView({ behavior: 'smooth' });
        }
    });
    
    // Initial load
    loadPhotos();
    
    // Auto refresh every 5 minutes
    setInterval(loadPhotos, 5 * 60 * 1000);
});
EOL

# Create Dockerfile
echo -e "\e[0;33mCreating Dockerfile...\e[0m"
cat > Dockerfile << 'EOL'
FROM arm32v7/nginx:alpine

COPY src/ /usr/share/nginx/html/
RUN mkdir -p /usr/share/nginx/html/photos

# Configure nginx
RUN echo 'server { \
    listen 80; \
    location / { \
        root /usr/share/nginx/html; \
        index index.html; \
    } \
    location /photos/ { \
        root /usr/share/nginx/html; \
        autoindex on; \
        autoindex_format html; \
    } \
}' > /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
EOL

# Create sample images
echo -e "\e[0;33mCreating sample images...\e[0m"

# Get current date and time for sample images
current_date=$(date +"%Y-%m-%d")

# Function to create sample SVG image with a given color and save as JPG
create_sample_image() {
    local index=$1
    local color=$2
    local hours_ago=$3
    
    # Calculate date time for the image
    local timestamp=$(date -d "$current_date - $hours_ago hours" +"%Y-%m-%d_%H-%M-%S")
    local display_date=$(date -d "$current_date - $hours_ago hours" +"%Y-%m-%d %H:%M:%S")
    
    # Create a simple SVG with the specified color
    cat > "src/photos/sample${index}_${timestamp}.jpg" << EOF
<svg width="800" height="600" xmlns="http://www.w3.org/2000/svg">
    <rect width="100%" height="100%" fill="${color}" />
    <text x="50%" y="50%" font-family="Arial" font-size="24" fill="white" text-anchor="middle">Sample ${index}: ${display_date}</text>
</svg>
EOF
    
    echo "Created sample${index}_${timestamp}.jpg"
}

# Create directory if it doesn't exist
mkdir -p src/photos

# Create 5 sample images with different colors and dates
create_sample_image 1 "#3498db" 1  # Blue, 1 hour ago
create_sample_image 2 "#2ecc71" 5  # Green, 5 hours ago
create_sample_image 3 "#e74c3c" 12  # Red, 12 hours ago
create_sample_image 4 "#f39c12" 24  # Orange, 24 hours ago
create_sample_image 5 "#9b59b6" 48  # Purple, 48 hours ago

# Make sure file permissions are correct
chmod -R 755 src/

# Create start server script
echo -e "\e[0;33mCreating start-server.sh...\e[0m"
cat > start-server.sh << 'EOL'
#!/bin/bash

echo -e "\e[1;36mStarting local web server for Daily Photo Gallery...\e[0m"

# Check for Python 3
if command -v python3 &>/dev/null; then
    echo -e "\e[0;32mFound Python 3\e[0m"
    cd src && python3 -m http.server 8000
    exit 0
fi

# Check for Python 2
if command -v python &>/dev/null; then
    echo -e "\e[0;32mFound Python 2\e[0m"
    cd src && python -m SimpleHTTPServer 8000
    exit 0
fi

# If no Python is found
echo -e "\e[0;31mPython not found. Cannot start built-in web server.\e[0m"
echo -e "\e[0;33mAlternative options:\e[0m"
echo -e "1. Install Python: https://www.python.org/downloads/"
echo -e "2. Use Docker: docker build -t photo-gallery . && docker run -p 8080:80 -v \$(pwd)/src/photos:/usr/share/nginx/html/photos photo-gallery"
echo -e "3. Use a different web server of your choice that can serve static files"

exit 1
EOL

# Make start-server.sh executable
chmod +x start-server.sh

# Create docker build script
echo -e "\e[0;33mCreating docker-build.sh...\e[0m"
cat > docker-build.sh << 'EOL'
#!/bin/bash

# Script to build Docker image for multiple architectures
echo -e "\e[1;36mBuilding Docker image for multiple architectures...\e[0m"

# Check if Docker is installed
if ! command -v docker &>/dev/null; then
    echo -e "\e[0;31mDocker is not installed or not in PATH. Please install Docker Desktop.\e[0m"
    exit 1
fi

# Show Docker version
docker_version=$(docker --version)
echo -e "\e[0;32mDocker version: $docker_version\e[0m"

# Check if Docker BuildX is available
if ! docker buildx version &>/dev/null; then
    echo -e "\e[0;33mDocker BuildX not available. Attempting to set up...\e[0m"
    
    # Try to create a new builder instance
    if ! docker buildx create --name mybuilder --use; then
        echo -e "\e[0;31mFailed to create Docker BuildX builder. Make sure Docker is properly installed.\e[0m"
        exit 1
    fi
    
    echo -e "\e[0;32mDocker BuildX builder created successfully.\e[0m"
else
    buildx_version=$(docker buildx version)
    echo -e "\e[0;32mDocker BuildX available: $buildx_version\e[0m"
fi

# Ask for Docker Hub username
read -p "Enter your Docker Hub username (leave blank to build locally only): " dockerHubUsername

# Set image name
if [ -n "$dockerHubUsername" ]; then
    imageName="${dockerHubUsername}/photo-gallery"
else
    imageName="photo-gallery"
fi

# Ask if user wants to push to Docker Hub
pushToHub=false
if [ -n "$dockerHubUsername" ]; then
    read -p "Push to Docker Hub? (y/n): " response
    if [ "${response,,}" = "y" ]; then
        pushToHub=true
    fi
fi

# Set up build command
buildCommand="docker buildx build --platform linux/amd64,linux/arm/v7 -t ${imageName}:latest"

if $pushToHub; then
    echo -e "\e[0;33mYou'll need to be logged in to Docker Hub. Checking login status...\e[0m"
    
    # Check if user is logged in to Docker Hub
    if ! docker info 2>&1 | grep -q "Username:"; then
        echo -e "\e[0;33mNot logged in to Docker Hub. Please log in:\e[0m"
        if ! docker login; then
            echo -e "\e[0;31mLogin failed. Aborting push to Docker Hub.\e[0m"
            pushToHub=false
        fi
    else
        loginInfo=$(docker info 2>&1 | grep "Username:")
        echo -e "\e[0;32mAlready logged in to Docker Hub as: $loginInfo\e[0m"
    fi
    
    if $pushToHub; then
        buildCommand="${buildCommand} --push"
    fi
fi

# Add load flag if not pushing
if ! $pushToHub; then
    buildCommand="${buildCommand} --load"
fi

# Add context
buildCommand="${buildCommand} ."

# Execute build
echo -e "\e[0;36mExecuting: $buildCommand\e[0m"
eval $buildCommand

# Check if build was successful
if [ $? -eq 0 ]; then
    echo -e "\n\e[0;32mBuild successful!\e[0m"
    
    if $pushToHub; then
        echo -e "\e[0;32mImage pushed to Docker Hub as ${imageName}:latest\e[0m"
        echo -e "\e[0;36mYou can pull it on your Raspberry Pi with: docker pull ${imageName}:latest\e[0m"
        echo -e "\e[0;36mAnd run it with: docker run -d -p 80:80 -v /path/to/photos:/usr/share/nginx/html/photos ${imageName}:latest\e[0m"
    else
        echo -e "\e[0;32mImage built locally as ${imageName}:latest\e[0m"
        echo -e "\e[0;36mYou can run it with: docker run -d -p 8080:80 -v \$(pwd)/src/photos:/usr/share/nginx/html/photos ${imageName}:latest\e[0m"
    fi
else
    echo -e "\n\e[0;31mBuild failed!\e[0m"
fi
EOL

# Make docker-build.sh executable
chmod +x docker-build.sh

# Create .gitignore
echo -e "\e[0;33mCreating .gitignore...\e[0m"
cat > .gitignore << 'EOL'
# Build artifacts
node_modules/
dist/
build/
*.min.js
*.min.css

# Configuration files
.env
.env.local
.env.*.local
config.json

# IDE and editor files
.idea/
.vscode/
*.swp
*.swo
*~
.DS_Store

# Logs
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Runtime data
pids
*.pid
*.seed
*.pid.lock

# Docker related
.docker/

# OS specific
.DS_Store
Thumbs.db

# Photo files that shouldn't be committed
# Users should maintain their own photos
src/photos/*.jpg
src/photos/*.jpeg
src/photos/*.png
src/photos/*.gif

# But include sample photos for demo
!src/photos/sample*.jpg
EOL

# Create GitHub workflow file
echo -e "\e[0;33mCreating GitHub workflow file...\e[0m"
mkdir -p .github/workflows
cat > .github/workflows/test.yml << 'EOL'
name: Test Daily Photo Gallery

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v2
    
    - name: Check file structure
      run: |
        if [ ! -d "src" ]; then
          echo "src directory missing"
          exit 1
        fi
        if [ ! -f "src/index.html" ]; then
          echo "index.html missing"
          exit 1
        fi
        if [ ! -f "src/styles.css" ]; then
          echo "styles.css missing"
          exit 1
        fi
        if [ ! -f "src/script.js" ]; then
          echo "script.js missing"
          exit 1
        fi
        echo "File structure looks good!"
    
    - name: Validate HTML
      run: |
        sudo apt-get update
        sudo apt-get install -y npm
        npm install -g html-validate
        html-validate src/index.html
    
    - name: Check Docker build
      run: |
        docker build -t photo-gallery-test .
        echo "Docker build successful!"
EOL

# Create README.md
echo -e "\e[0;33mCreating README.md...\e[0m"
cat > README.md << 'EOL'
# Daily Photo Gallery

A lightweight and responsive photo gallery application designed to display daily photos in chronological order. Perfect for Raspberry Pi and other small devices.

## Features

- **Latest Photo View:** Shows the most recent photo with date and time
- **Gallery View:** Browse all photos with pagination
- **Responsive Design:** Works on desktop, tablet, and mobile devices
- **Auto-Refresh:** Updates automatically every 5 minutes
- **New Photo Indicator:** Highlights photos less than 24 hours old
- **Simple Setup:** Easy to deploy on Raspberry Pi or any web server
- **Docker Support:** Ready for containerized deployment

## Quick Start

### Prerequisites

- Bash shell environment (Linux or macOS)
- For local testing: Python (2 or 3) or Docker
- For deployment: Raspberry Pi with Docker (optional)

### Setup

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/daily-photo-gallery.git
   cd daily-photo-gallery
   ```

2. Run the setup script:
   ```bash
   ./setup.sh
   ```

3. Start a local test server:
   ```bash
   ./start-server.sh
   ```

4. Open http://localhost:8000 in your web browser

### Docker Deployment

To build and run with Docker:

```bash
# Build Docker image
./docker-build.sh

# Run locally
docker run -d -p 8080:80 -v $(pwd)/src/photos:/usr/share/nginx/html/photos photo-gallery

# Access at http://localhost:8080
```

### Raspberry Pi Deployment

On your Raspberry Pi:

1. Install Docker:
   ```bash
   curl -sSL https://get.docker.com | sh
   sudo usermod -aG docker pi
   ```

2. Pull and run the Docker image:
   ```bash
   docker run -d -p 80:80 -v /path/to/photos:/usr/share/nginx/html/photos yourusername/photo-gallery
   ```

3. Access at http://raspberrypi.local or http://[your-pi-ip]

## Adding Photos

1. Place your photos in the `src/photos` directory
2. Name photos using the format: `YYYY-MM-DD_HH-MM-SS.jpg` (e.g., `2023-05-25_14-30-00.jpg`)
3. The gallery will automatically sort and display them chronologically

## Directory Structure

```
daily-photo-gallery/
├── Dockerfile
├── docker-build.sh
├── setup.sh
├── start-server.sh
├── src/
│   ├── index.html
│   ├── styles.css
│   ├── script.js
│   └── photos/
│       └── (your photos go here)
└── README.md
```

## Customization

- Edit `src/styles.css` to customize colors, fonts, and layout
- Modify `src/index.html` for structural changes
- Update `src/script.js` to change behavior or add features

## Troubleshooting

- **No photos appear:** Ensure your photos are named correctly (YYYY-MM-DD_HH-MM-SS.jpg)
- **Server won't start:** Try using Docker or install Python if it's not available
- **Docker build fails:** Ensure Docker is installed and properly configured
- **Images don't load on Raspberry Pi:** Check directory permissions and volume mounting

## License

MIT License - See LICENSE file for details

## Contributing

Contributions welcome! Please feel free to submit a Pull Request.
EOL

# Final message
echo -e "\n\e[1;32mSetup complete!\e[0m"
echo -e "\e[1;33mTo start a local web server, run: ./start-server.sh\e[0m"
echo -e "\e[1;33mTo build a Docker image, run: ./docker-build.sh\e[0m"
echo -e "\e[1;33mSee README.md for more information.\e[0m"
