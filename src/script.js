// DOM Elements
const latestTab = document.getElementById('latest-tab');
const latestTabText = document.getElementById('latest-tab-text');
const galleryTab = document.getElementById('gallery-tab');
const latestView = document.getElementById('latest-view');
const galleryView = document.getElementById('gallery-view');
const latestPhoto = document.getElementById('latest-photo');
const latestDate = document.getElementById('latest-date');
const refreshTime = document.getElementById('refresh-time');
const galleryPhoto = document.getElementById('gallery-photo');
const galleryDate = document.getElementById('gallery-date');
const firstButton = document.getElementById('first-photo');
const prevButton = document.getElementById('prev-photo');
const nextButton = document.getElementById('next-photo');
const latestButton = document.getElementById('latest-button');
const gallerySlider = document.getElementById('gallery-slider');
const loadingDoughnut = document.getElementById('loading-doughnut');
const progressIndicator = document.querySelector('.progress-indicator');
const progressText = document.querySelector('.progress-text');
const maximizeOverlay = document.getElementById('maximize-overlay');
const maximizedPhoto = document.getElementById('maximized-photo');
const closeMaximizeButton = document.getElementById('close-maximize');

// Application State
let photos = [];
let currentPhotoIndex = 0;
let lastCheckTime = null;
let isLatestToday = false;
let originalViewportContent = null; // Store original viewport settings
let preloadedImages = new Set(); // Track which thumbnails have been preloaded
let webRequestedImages = new Set(); // Web-sized images whose download has started
let webLoadedImages = new Set(); // Web-sized images that finished downloading
let currentFrameToken = 0; // Guards against a slow image landing after the user moved on
let loadingProgress = 0; // Track image loading progress (0-100%)
let totalImagesToLoad = 0; // Keep track of total images to load
let isPreloadAnimating = false; // Flag to track if we're in preload animation mode
let userInteracted = false; // Flag to track if user has interacted with gallery controls
let currentlyDisplayedDate = null; // Track the date of the currently displayed photo during animation

// Configuration

// Photos live in Cloudflare R2 and are served through a custom domain.
// R2 has no directory listing, so the sync job on the capture Pi writes a
// photos.json index alongside them (this replaces parsing nginx autoindex HTML).
const PHOTO_BASE = 'https://img.vilugill.com';
const MANIFEST_URL = `${PHOTO_BASE}/photos.json`;

// Fallback tier layout, used if the manifest doesn't declare its own.
const DEFAULT_TIERS = {
    thumb: { dir: 'thumb', ext: 'webp' },  // ~22KB  - preloaded across the whole timelapse
    web:   { dir: 'web',   ext: 'webp' },  // ~167KB - shown while scrubbing
    full:  { dir: 'full',  ext: 'jpg'  }   // ~700KB - Latest view and maximised view
};

// How many photos either side of the current one to fetch at web quality.
const WEB_PREFETCH_WINDOW = 8;

// How many thumbnails to download at once during the initial timelapse preload.
const PRELOAD_CONCURRENCY = 10;

// Tab Navigation
latestTab.addEventListener('click', (e) => {
    e.preventDefault();
    activateTab(latestTab, latestView);
});

galleryTab.addEventListener('click', (e) => {
    e.preventDefault();
    activateTab(galleryTab, galleryView);
});

function activateTab(tabElement, viewElement) {
    // Update tab state
    latestTab.classList.remove('active');
    galleryTab.classList.remove('active');
    tabElement.classList.add('active');
    
    // Update view state
    latestView.classList.remove('active');
    galleryView.classList.remove('active');
    viewElement.classList.add('active');
}

// Gallery Navigation - Reversed logic (previous = newer, next = older)
prevButton.addEventListener('click', () => {
    if (currentPhotoIndex < photos.length - 1) {
        currentPhotoIndex++;
        updateGalleryView();
    }
});

nextButton.addEventListener('click', () => {
    if (currentPhotoIndex > 0) {
        currentPhotoIndex--;
        updateGalleryView();
    }
});

// First button (jump to oldest photo)
firstButton.addEventListener('click', () => {
    if (photos.length > 0) {
        currentPhotoIndex = photos.length - 1;
        updateGalleryView();
    }
});

// Latest button (jump to newest photo)
latestButton.addEventListener('click', () => {
    if (photos.length > 0) {
        currentPhotoIndex = 0;
        updateGalleryView();
    }
});

// Add event listeners to track user interaction during preloading
function trackUserInteraction() {
    if (isPreloadAnimating) {
        userInteracted = true;
        console.log("User interaction detected, stopping preload animation");
    }
}

// Add interaction tracking to all navigation controls
firstButton.addEventListener('click', trackUserInteraction);
prevButton.addEventListener('click', trackUserInteraction);
nextButton.addEventListener('click', trackUserInteraction);
latestButton.addEventListener('click', trackUserInteraction);

// Slider control for navigating photos
gallerySlider.addEventListener('input', () => {
    trackUserInteraction();
    // Calculate the new index based on slider value
    // Oldest photos (higher indices in array) = left (0)
    // Newest photos (lower indices in array) = right (100)
    const newIndex = Math.round((photos.length - 1) * (1 - (gallerySlider.value / 100)));
    if (newIndex !== currentPhotoIndex) {
        currentPhotoIndex = newIndex;
        updateGalleryView();
    }
});

// Build the per-tier URLs for one date, honouring whatever layout the manifest declares.
function buildPhoto(date, tiers) {
    const url = (key) => {
        const tier = (tiers && tiers[key]) || DEFAULT_TIERS[key];
        return `${PHOTO_BASE}/${tier.dir}/${date}.${tier.ext}`;
    };
    return { date, thumb: url('thumb'), web: url('web'), full: url('full') };
}

// Fetch the photo index from R2.
// The manifest is small (a few KB) and short-cached, so a new day's photo shows
// up within minutes of the Pi uploading it.
async function fetchManifest() {
    const response = await fetch(MANIFEST_URL, { cache: 'no-cache' });
    if (!response.ok) {
        throw new Error(`Manifest request failed: HTTP ${response.status}`);
    }

    const data = await response.json();
    const dates = Array.isArray(data.dates) ? data.dates : [];
    if (dates.length === 0) {
        throw new Error('Manifest contained no photos');
    }

    return dates.map(date => buildPhoto(date, data.tiers));
}

// Function to load the photo index and refresh both views
async function scanDirectory() {
    try {
        const files = await fetchManifest();

        // Sort photos by date (newest first)
        photos = files.sort((a, b) => {
            return new Date(b.date) - new Date(a.date);
        });

        // Update views
        updateLatestPhotoView();
        updateGalleryView();

        // Update slider max value
        gallerySlider.max = 100;

        // Update last check time
        lastCheckTime = new Date();
        updateRefreshTime();

        return photos.length > 0;
    } catch (error) {
        console.error('Could not load the photo index:', error);
        photos = [];
        updateLatestPhotoView();
        updateGalleryView();
        latestDate.textContent = 'Photos unavailable - please try again shortly';
        return false;
    }
}

// Update Latest Photo View
function updateLatestPhotoView() {
    if (photos.length > 0) {
        const latest = photos[0];
        
        // Set onload handler (preloading is now done on initial page load)
        latestPhoto.onload = function() {
            // We no longer need to preload here as it's handled on initial page load
        };
        
        latestPhoto.src = latest.full;
        latestPhoto.alt = `Photo from ${latest.date}`;
        latestDate.textContent = formatDate(latest.date);
        
        // Add animation for new photos
        latestPhoto.classList.add('new-photo');
        setTimeout(() => {
            latestPhoto.classList.remove('new-photo');
        }, 2000);
        
        // Check if latest photo is from today or yesterday
        const today = new Date();
        const yesterday = new Date(today);
        yesterday.setDate(yesterday.getDate() - 1);
        const photoDate = new Date(latest.date);
        
        const isToday = (today.getFullYear() === photoDate.getFullYear() && 
                        today.getMonth() === photoDate.getMonth() && 
                        today.getDate() === photoDate.getDate());
                        
        const isYesterday = (yesterday.getFullYear() === photoDate.getFullYear() && 
                           yesterday.getMonth() === photoDate.getMonth() && 
                           yesterday.getDate() === photoDate.getDate());
        
        // Update the tab text
        if (isToday) {
            latestTabText.textContent = "Today";
        } else if (isYesterday) {
            latestTabText.textContent = "Yesterday";
        } else {
            latestTabText.textContent = "Latest";
        }
        
        isLatestToday = isToday;
    } else {
        latestPhoto.src = '';
        latestDate.textContent = 'No photos available';
        latestTabText.textContent = "Latest";
        isLatestToday = false;
    }
}

// Function to update button states with better Firefox compatibility
function updateButtonStates() {
    const isOldest = currentPhotoIndex === photos.length - 1;
    const isNewest = currentPhotoIndex === 0;

    // Helper function to update button state
    const setButtonState = (button, disabled) => {
        button.disabled = disabled;
        if (disabled) {
            button.setAttribute('disabled', '');
            button.setAttribute('aria-disabled', 'true');
        } else {
            button.removeAttribute('disabled');
            button.removeAttribute('aria-disabled');
        }
    };

    // Update all buttons
    setButtonState(firstButton, isOldest);
    setButtonState(prevButton, isOldest);
    setButtonState(nextButton, isNewest);
    setButtonState(latestButton, isNewest);
}

// Show one frame in the timelapse view.
// Thumbnails are preloaded for every photo, so they paint instantly; the sharper
// web-sized image is then fetched in the background and swapped in. A late
// arrival is discarded if the user has already scrubbed somewhere else.
function showGalleryFrame(photo, isAnimating = false) {
    // While the initial preload is walking through the build, stay on thumbnails -
    // upgrading every frame it passes would pull the entire web-sized set.
    if (isAnimating) {
        galleryPhoto.src = photo.thumb;
        return;
    }

    const token = ++currentFrameToken;

    if (webLoadedImages.has(photo.web)) {
        galleryPhoto.src = photo.web;
    } else {
        galleryPhoto.src = photo.thumb;

        const upgrade = new Image();
        upgrade.onload = () => {
            webLoadedImages.add(photo.web);
            // Only swap in if this is still the frame on screen
            if (token === currentFrameToken) {
                galleryPhoto.src = photo.web;
            }
        };
        upgrade.src = photo.web;
        webRequestedImages.add(photo.web);
    }

    prefetchWebWindow(currentPhotoIndex);
}

// Keep a window of web-sized images either side of the current frame warm, so
// stepping day by day feels instant without pulling all of them.
function prefetchWebWindow(centreIndex) {
    for (let offset = -WEB_PREFETCH_WINDOW; offset <= WEB_PREFETCH_WINDOW; offset++) {
        const photo = photos[centreIndex + offset];
        if (!photo) continue;
        if (webLoadedImages.has(photo.web) || webRequestedImages.has(photo.web)) continue;

        webRequestedImages.add(photo.web);
        const img = new Image();
        img.onload = () => webLoadedImages.add(photo.web);
        img.src = photo.web;
    }
}

// Full-resolution source for the currently selected photo (used by the maximised view)
function currentFullSrc() {
    const photo = photos[currentPhotoIndex];
    return photo ? photo.full : '';
}

// Update Gallery View
function updateGalleryView(isAnimating = false) {
    if (photos.length > 0) {
        const photo = photos[currentPhotoIndex];
        showGalleryFrame(photo, isAnimating);
        galleryPhoto.alt = `Photo from ${photo.date}`;
        galleryDate.textContent = formatDate(photo.date, true);
        
        // Update currentlyDisplayedDate when manually navigating
        if (!isAnimating) {
            currentlyDisplayedDate = new Date(photo.date).getTime();
        }
        
        // Update button states with these variables
        const isOldest = currentPhotoIndex === photos.length - 1;
        const isNewest = currentPhotoIndex === 0;
        
        // Call updateButtonStates
        updateButtonStates();
        
        // Add logging for debugging
        console.log(`Button States - First: ${isOldest}, Latest: ${isNewest}`);
        console.log(`First button has disabled attribute: ${firstButton.hasAttribute('disabled')}`);
        console.log(`Latest button has disabled attribute: ${latestButton.hasAttribute('disabled')}`);
        
        // Previous and Next buttons remain with fixed text
        prevButton.textContent = "Previous Day";
        nextButton.textContent = "Next Day";
        
        // Update Latest button text
        if (photos.length > 0) {
            const latestPhoto = photos[0];
            const isLatestToday = formatDate(latestPhoto.date, true) === "Today";
            const isLatestYesterday = formatDate(latestPhoto.date, true) === "Yesterday";
            latestButton.textContent = isLatestToday || isLatestYesterday ? formatDate(latestPhoto.date, true) : "Latest";
        } else {
            latestButton.textContent = "Latest";
        }
        
        // Update counter (showing index + 1 to be more user-friendly)
        // Photo counter removed
        
        // Update slider value
        // Newest photos (index 0) should be at the right (100)
        // Oldest photos (index photos.length-1) should be at the left (0)
        gallerySlider.value = 100 - ((currentPhotoIndex / (photos.length - 1)) * 100);
        
        // Check if this is today's photo
        const today = new Date();
        const photoDate = new Date(photo.date);
        
        const isPhotoFromToday = (today.getFullYear() === photoDate.getFullYear() && 
                                  today.getMonth() === photoDate.getMonth() && 
                                  today.getDate() === photoDate.getDate());
        
        // Special styling for today's photo
        if (isPhotoFromToday) {
            galleryDate.classList.add('today');
        } else {
            galleryDate.classList.remove('today');
        }
    } else {
        galleryPhoto.src = '';
        galleryDate.textContent = 'No photos available';
        
        // Disable all buttons using the updateButton helper for better Firefox compatibility
        [firstButton, prevButton, nextButton, latestButton].forEach(button => {
            // Remove attributes first
            button.removeAttribute('disabled');
            button.removeAttribute('aria-disabled');
            
            // Then set disabled state
            button.disabled = true;
            button.setAttribute('disabled', 'disabled');
            button.setAttribute('aria-disabled', 'true');
        });
        
        prevButton.textContent = "Previous Day";
        nextButton.textContent = "Next Day";
        latestButton.textContent = "Latest";
        gallerySlider.disabled = true;
    }
}

// Update Refresh Time Display
function updateRefreshTime() {
    if (lastCheckTime) {
        refreshTime.textContent = `Last updated: ${lastCheckTime.toLocaleTimeString()}`;
    }
}

// Format Date for Display
function formatDate(dateString, showRelative = true) {
    const date = new Date(dateString);
    
    // Check if the date is today or yesterday
    const today = new Date();
    const yesterday = new Date(today);
    yesterday.setDate(yesterday.getDate() - 1);
    
    const isToday = (today.getFullYear() === date.getFullYear() && 
                     today.getMonth() === date.getMonth() && 
                     today.getDate() === date.getDate());
                     
    const isYesterday = (yesterday.getFullYear() === date.getFullYear() && 
                         yesterday.getMonth() === date.getMonth() && 
                         yesterday.getDate() === date.getDate());
    
    // If showing relative dates and the date is today or yesterday
    if (showRelative && (isToday || isYesterday)) {
        return isToday ? "Today" : "Yesterday";
    }
    
    // For gallery view, don't include the day of week
    if (document.activeElement === gallerySlider || 
        document.activeElement === prevButton || 
        document.activeElement === nextButton ||
        document.activeElement === firstButton ||
        document.activeElement === latestButton ||
        galleryView.classList.contains('active')) {
        return date.toLocaleDateString(undefined, { 
            year: 'numeric', 
            month: 'long', 
            day: 'numeric' 
        });
    }
    
    // For latest view, include the day of week
    return date.toLocaleDateString(undefined, { 
        weekday: 'long', 
        year: 'numeric', 
        month: 'long', 
        day: 'numeric' 
    });
}

// Keyboard navigation
document.addEventListener('keydown', (e) => {
    // Check if we're in gallery view or maximized view
    if (galleryView.classList.contains('active') || maximizeOverlay.classList.contains('visible')) {
        switch (e.key) {
            case 'ArrowLeft':
                // Previous (newer) photo
                if (!prevButton.hasAttribute('disabled')) {
                    prevButton.click();
                    // Update maximized photo if in maximized view
                    if (maximizeOverlay.classList.contains('visible')) {
                        maximizedPhoto.src = currentFullSrc();
                        maximizedPhoto.alt = galleryPhoto.alt;
                    }
                }
                break;
            case 'ArrowRight':
                // Next (older) photo
                if (!nextButton.hasAttribute('disabled')) {
                    nextButton.click();
                    // Update maximized photo if in maximized view
                    if (maximizeOverlay.classList.contains('visible')) {
                        maximizedPhoto.src = currentFullSrc();
                        maximizedPhoto.alt = galleryPhoto.alt;
                    }
                }
                break;
            case 'ArrowUp':
                // Go to newest photo (latest)
                if (!latestButton.hasAttribute('disabled')) {
                    latestButton.click();
                    // Update maximized photo if in maximized view
                    if (maximizeOverlay.classList.contains('visible')) {
                        maximizedPhoto.src = currentFullSrc();
                        maximizedPhoto.alt = galleryPhoto.alt;
                    }
                }
                break;
            case 'ArrowDown':
                // Go to oldest photo (first)
                if (!firstButton.hasAttribute('disabled')) {
                    firstButton.click();
                    // Update maximized photo if in maximized view
                    if (maximizeOverlay.classList.contains('visible')) {
                        maximizedPhoto.src = currentFullSrc();
                        maximizedPhoto.alt = galleryPhoto.alt;
                    }
                }
                break;
        }
    }
});

// Photo Maximization
function showMaximizedPhoto(src, alt) {
    // Store original viewport settings before updating
    const viewportMeta = document.getElementById('viewport-meta');
    originalViewportContent = viewportMeta.content;
    
    // Update viewport to allow pinch-zoom on mobile
    viewportMeta.content = 'width=device-width, initial-scale=1.0, user-scalable=yes';
    
    maximizedPhoto.src = src;
    maximizedPhoto.alt = alt;
    maximizeOverlay.classList.remove('hidden');
    maximizeOverlay.classList.add('visible');
    document.body.style.overflow = 'hidden'; // Prevent scrolling
}

function hideMaximizedPhoto() {
    // Restore original viewport settings
    const viewportMeta = document.getElementById('viewport-meta');
    viewportMeta.content = originalViewportContent || 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
    
    maximizeOverlay.classList.remove('visible');
    maximizeOverlay.classList.add('hidden');
    document.body.style.overflow = ''; // Restore scrolling
    
    // Reset zoom level on mobile devices
    resetZoom();
}

// Add maximize functionality to both photos
latestPhoto.addEventListener('click', () => {
    showMaximizedPhoto(latestPhoto.src, latestPhoto.alt);
});

galleryPhoto.addEventListener('click', () => {
    showMaximizedPhoto(currentFullSrc(), galleryPhoto.alt);
});

closeMaximizeButton.addEventListener('click', () => {
    hideMaximizedPhoto();
});

// Close on escape key
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && maximizeOverlay.classList.contains('visible')) {
        hideMaximizedPhoto();
    }
});

// Ensure proper touch handling for maximized photo
let touchStartTime = 0;
let touchStartX = 0;
let touchStartY = 0;
let hasMoved = false;
let touchTimeout = null;

maximizedPhoto.addEventListener('touchstart', (e) => {
    // Allow default touch behavior for pinch-to-zoom
    e.stopPropagation();
    
    // Reset touch tracking variables
    touchStartTime = Date.now();
    touchStartX = e.touches[0].clientX;
    touchStartY = e.touches[0].clientY;
    hasMoved = false;
    
    // Clear any existing timeout
    if (touchTimeout) {
        clearTimeout(touchTimeout);
    }
}, { passive: true });

maximizedPhoto.addEventListener('touchmove', (e) => {
    // Allow default touch behavior for panning
    e.stopPropagation();
    
    // Check if user has moved significantly (indicating pan/zoom, not a tap)
    const touchX = e.touches[0].clientX;
    const touchY = e.touches[0].clientY;
    const deltaX = Math.abs(touchX - touchStartX);
    const deltaY = Math.abs(touchY - touchStartY);
    
    // If moved more than 10px in any direction, consider it a pan/zoom
    if (deltaX > 10 || deltaY > 10 || e.touches.length > 1) {
        hasMoved = true;
    }
}, { passive: true });

maximizedPhoto.addEventListener('touchend', (e) => {
    // Tap-to-exit functionality removed
    // Only using X button and Escape key to exit maximized view
}, { passive: true });

// Click event listener removed - maximized photos no longer close on tap/click

// Function to reset zoom level
function resetZoom() {
    // Force reset zoom on mobile by temporarily setting and then removing a meta tag
    const tempMeta = document.createElement('meta');
    tempMeta.name = 'viewport';
    tempMeta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
    document.head.appendChild(tempMeta);
    
    // Small delay to ensure the meta tag is applied before removing
    setTimeout(() => {
        document.head.removeChild(tempMeta);
    }, 100);
    
    // For desktop browsers, try to reset zoom programmatically
    if (window.devicePixelRatio !== undefined) {
        // This helps reset zoom in some browsers
        document.body.style.zoom = 1;
        setTimeout(() => {
            document.body.style.zoom = '';
        }, 50);
    }
}

// Function to calculate and update loading progress
function updateLoadingProgress(percent) {
    const doughnut = document.getElementById('loading-doughnut');
    const indicator = doughnut?.querySelector('.progress-indicator');
    const text = doughnut?.querySelector('.progress-text');
    if (!doughnut || !indicator || !text) return;

    // Update text
    text.textContent = `${Math.round(percent)}%`;

    // Update progress path
    indicator.style.strokeDashoffset = 100 - percent;

    // Show/hide the doughnut
    if (percent === 0) {
        doughnut.classList.remove('hidden');
    } else if (percent === 100) {
        setTimeout(() => doughnut.classList.add('hidden'), 300);
    }
}

// Function to preload all gallery images
function preloadGalleryImages() {
    if (photos.length === 0) return;

    let loadedCount = 0;
    let settledCount = 0;
    let nextToStart = 0;
    const totalImages = photos.length;
    const loadedDates = new Map();

    // Show initial loading state
    updateLoadingProgress(0);
    currentlyDisplayedDate = null;

    // Create an array of photos sorted by date (newest to oldest)
    const sortedPhotos = [...photos].sort((a, b) => {
        return new Date(b.date) - new Date(a.date);
    });

    const startNext = () => {
        if (nextToStart >= sortedPhotos.length) return;

        const photo = sortedPhotos[nextToStart++];
        const img = new Image();
        const date = new Date(photo.date).getTime();

        img.onload = () => {
            loadedCount++;
            preloadedImages.add(photo.thumb);
            loadedDates.set(date, photos.findIndex(p => p.date === photo.date));

            // Update progress based on successfully loaded images
            const progress = Math.round((loadedCount / totalImages) * 100);
            updateLoadingProgress(progress);

            // If in gallery view, update to show oldest loaded image
            if (galleryView.classList.contains('active')) {
                const oldestLoadedDate = Math.min(...loadedDates.keys());
                if (!currentlyDisplayedDate || oldestLoadedDate < currentlyDisplayedDate) {
                    currentPhotoIndex = loadedDates.get(oldestLoadedDate);
                    currentlyDisplayedDate = oldestLoadedDate;
                    updateGalleryView(true);
                }
            }

            settled();
        };

        img.onerror = () => {
            console.error(`Failed to load image: ${photo.thumb}`);
            // Don't count failed images in the progress
            settled();
        };

        img.src = photo.thumb;
    };

    const settled = () => {
        settledCount++;

        // Once the whole timelapse is preloaded, sharpen whatever ended up on screen
        if (settledCount === totalImages && galleryView.classList.contains('active')) {
            updateGalleryView();
        }

        startNext();
    };

    // Run a bounded number of downloads at a time rather than firing all of them
    // at once, which keeps the walk-through smooth and the connection responsive
    for (let i = 0; i < Math.min(PRELOAD_CONCURRENCY, sortedPhotos.length); i++) {
        startNext();
    }
}

// Photo Gallery Web App v1.2.0

// Initialize the Application
window.addEventListener('DOMContentLoaded', () => {
    // Store original viewport settings
    const viewportMeta = document.getElementById('viewport-meta');
    if (viewportMeta) {
        originalViewportContent = viewportMeta.content;
    }
    
    // Initial scan
    scanDirectory().then(hasPhotos => {
        if (hasPhotos) {
            // Ensure the loading doughnut is visible before starting preload
            if (loadingDoughnut) {
                loadingDoughnut.classList.remove('hidden');
                // Reset progress to zero
                setTimeout(() => {
                    updateLoadingProgress(0);
                }, 0);
            }
            
            // Start preloading images immediately, regardless of active view
            setTimeout(() => {
                preloadGalleryImages();
            }, 100); // Small delay to ensure DOM updates are visible
        }
    });
    
    // No refresh interval - images preload immediately on initial page load
});
