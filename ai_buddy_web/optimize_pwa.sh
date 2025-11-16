#!/bin/bash
#
# Flutter Web PWA Optimization Script
# Optimizes bundle size, enables PWA features, and improves performance
#

set -e

echo "🚀 Flutter Web PWA Optimization Starting..."

# Navigate to Flutter app directory
cd "$(dirname "$0")"

# Step 1: Clean build artifacts
echo "📦 Cleaning old build artifacts..."
flutter clean
rm -rf build/

# Step 2: Update pubspec.yaml for optimization
echo "⚙️ Configuring build optimizations..."

# Step 3: Build optimized web app
echo "🔨 Building optimized Flutter web app..."
flutter build web \
  --release \
  --web-renderer canvaskit \
  --tree-shake-icons \
  --no-source-maps \
  --pwa-strategy offline-first

# Step 4: Additional optimizations
echo "🎯 Applying post-build optimizations..."

# Compress JavaScript
if command -v terser &> /dev/null; then
  echo "  Compressing JavaScript with Terser..."
  find build/web -name "*.js" -not -name "*.min.js" -exec terser {} -c -m -o {} \;
else
  echo "  Terser not found, skipping JS compression"
fi

# Compress CSS
if command -v csso &> /dev/null; then
  echo "  Compressing CSS with CSSO..."
  find build/web -name "*.css" -exec csso {} -o {} \;
else
  echo "  CSSO not found, skipping CSS compression"
fi

# Generate optimized images
echo "🖼️ Optimizing images..."
if command -v imagemin &> /dev/null; then
  imagemin build/web/assets/images/* --out-dir=build/web/assets/images
else
  echo "  imagemin not found, skipping image optimization"
fi

# Step 5: Update manifest.json for better PWA
echo "📱 Updating PWA manifest..."
cat > build/web/manifest.json << 'EOF'
{
    "name": "GentleQuest - AI Mental Health Assistant",
    "short_name": "GentleQuest",
    "description": "Your AI-powered mental health companion",
    "start_url": "/",
    "display": "standalone",
    "background_color": "#FFFFFF",
    "theme_color": "#6750A4",
    "orientation": "portrait",
    "categories": ["health", "medical", "lifestyle"],
    "scope": "/",
    "lang": "en",
    "dir": "ltr",
    "icons": [
        {
            "src": "icons/icon-72.png",
            "sizes": "72x72",
            "type": "image/png",
            "purpose": "any maskable"
        },
        {
            "src": "icons/icon-96.png",
            "sizes": "96x96",
            "type": "image/png",
            "purpose": "any maskable"
        },
        {
            "src": "icons/icon-128.png",
            "sizes": "128x128",
            "type": "image/png",
            "purpose": "any maskable"
        },
        {
            "src": "icons/icon-144.png",
            "sizes": "144x144",
            "type": "image/png",
            "purpose": "any maskable"
        },
        {
            "src": "icons/icon-152.png",
            "sizes": "152x152",
            "type": "image/png",
            "purpose": "any maskable"
        },
        {
            "src": "icons/icon-192.png",
            "sizes": "192x192",
            "type": "image/png",
            "purpose": "any maskable"
        },
        {
            "src": "icons/icon-384.png",
            "sizes": "384x384",
            "type": "image/png",
            "purpose": "any maskable"
        },
        {
            "src": "icons/icon-512.png",
            "sizes": "512x512",
            "type": "image/png",
            "purpose": "any maskable"
        }
    ],
    "screenshots": [
        {
            "src": "screenshots/chat.png",
            "sizes": "540x960",
            "type": "image/png",
            "label": "Chat with AI Assistant"
        },
        {
            "src": "screenshots/mood.png",
            "sizes": "540x960",
            "type": "image/png",
            "label": "Track Your Mood"
        },
        {
            "src": "screenshots/dashboard.png",
            "sizes": "540x960",
            "type": "image/png",
            "label": "Wellness Dashboard"
        }
    ],
    "shortcuts": [
        {
            "name": "Chat",
            "short_name": "Chat",
            "description": "Start a conversation",
            "url": "/chat",
            "icons": [{"src": "icons/chat.png", "sizes": "96x96"}]
        },
        {
            "name": "Mood",
            "short_name": "Mood",
            "description": "Track your mood",
            "url": "/mood",
            "icons": [{"src": "icons/mood.png", "sizes": "96x96"}]
        }
    ],
    "prefer_related_applications": false,
    "related_applications": []
}
EOF

# Step 6: Create optimized service worker
echo "⚙️ Creating optimized service worker..."
cat > build/web/flutter_service_worker.js << 'EOF'
'use strict';

const CACHE_NAME = 'gentlequest-v1.0.0';
const urlsToCache = [
  '/',
  '/index.html',
  '/main.dart.js',
  '/flutter.js',
  '/manifest.json',
  '/assets/AssetManifest.json',
  '/assets/FontManifest.json'
];

// Install event - cache critical resources
self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME).then(cache => {
      console.log('Opened cache');
      return cache.addAll(urlsToCache);
    })
  );
  self.skipWaiting();
});

// Activate event - clean old caches
self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(cacheNames => {
      return Promise.all(
        cacheNames.filter(cacheName => {
          return cacheName !== CACHE_NAME;
        }).map(cacheName => {
          return caches.delete(cacheName);
        })
      );
    })
  );
  self.clients.claim();
});

// Fetch event - serve from cache, fallback to network
self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);
  
  // Skip non-GET requests
  if (event.request.method !== 'GET') {
    return;
  }
  
  // Skip API calls
  if (url.pathname.startsWith('/api/')) {
    return;
  }
  
  event.respondWith(
    caches.match(event.request).then(response => {
      // Cache hit - return response
      if (response) {
        return response;
      }
      
      // Clone request for network fetch
      const fetchRequest = event.request.clone();
      
      return fetch(fetchRequest).then(response => {
        // Check if valid response
        if (!response || response.status !== 200 || response.type !== 'basic') {
          return response;
        }
        
        // Clone response for caching
        const responseToCache = response.clone();
        
        caches.open(CACHE_NAME).then(cache => {
          cache.put(event.request, responseToCache);
        });
        
        return response;
      }).catch(() => {
        // Return offline page if available
        return caches.match('/offline.html');
      });
    })
  );
});

// Background sync for offline actions
self.addEventListener('sync', event => {
  if (event.tag === 'sync-messages') {
    event.waitUntil(syncMessages());
  }
});

// Push notifications
self.addEventListener('push', event => {
  const options = {
    body: event.data ? event.data.text() : 'New update from GentleQuest',
    icon: '/icons/icon-192.png',
    badge: '/icons/badge.png',
    vibrate: [200, 100, 200],
    data: {
      timestamp: new Date().toISOString()
    }
  };
  
  event.waitUntil(
    self.registration.showNotification('GentleQuest', options)
  );
});

// Notification click handler
self.addEventListener('notificationclick', event => {
  event.notification.close();
  event.waitUntil(
    clients.openWindow('/')
  );
});

// Helper function to sync offline messages
async function syncMessages() {
  try {
    // Get offline messages from IndexedDB
    const messages = await getOfflineMessages();
    
    // Send to server
    for (const message of messages) {
      await fetch('/api/chat', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Session-ID': message.sessionId
        },
        body: JSON.stringify({ message: message.text })
      });
      
      // Remove from offline storage
      await removeOfflineMessage(message.id);
    }
  } catch (error) {
    console.error('Sync failed:', error);
  }
}

// IndexedDB functions (simplified)
function getOfflineMessages() {
  return new Promise((resolve) => {
    // Simplified - would use actual IndexedDB
    resolve([]);
  });
}

function removeOfflineMessage(id) {
  return Promise.resolve();
}
EOF

# Step 7: Create offline fallback page
echo "📄 Creating offline page..."
cat > build/web/offline.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>GentleQuest - Offline</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            min-height: 100vh;
            margin: 0;
            background: linear-gradient(135deg, #6750A4 0%, #8B7AA8 100%);
            color: white;
            text-align: center;
            padding: 20px;
        }
        .container {
            max-width: 400px;
        }
        h1 {
            font-size: 2.5rem;
            margin-bottom: 1rem;
        }
        p {
            font-size: 1.1rem;
            line-height: 1.6;
            margin-bottom: 2rem;
            opacity: 0.9;
        }
        button {
            background: white;
            color: #6750A4;
            border: none;
            padding: 12px 24px;
            font-size: 1rem;
            font-weight: 600;
            border-radius: 24px;
            cursor: pointer;
            transition: transform 0.2s;
        }
        button:hover {
            transform: scale(1.05);
        }
        .icon {
            font-size: 4rem;
            margin-bottom: 1rem;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="icon">📡</div>
        <h1>You're Offline</h1>
        <p>GentleQuest needs an internet connection to provide AI-powered support. Please check your connection and try again.</p>
        <button onclick="window.location.reload()">Try Again</button>
    </div>
    <script>
        // Auto-reload when connection is restored
        window.addEventListener('online', function() {
            window.location.reload();
        });
    </script>
</body>
</html>
EOF

# Step 8: Add performance hints to index.html
echo "🎨 Optimizing index.html..."
if [ -f build/web/index.html ]; then
  # Add preload hints (simplified - would use proper HTML parser)
  sed -i.bak '/<head>/a\
  <link rel="preconnect" href="https://fonts.googleapis.com">\
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>\
  <link rel="dns-prefetch" href="https://gentlequest.onrender.com">\
  <meta name="apple-mobile-web-app-capable" content="yes">\
  <meta name="apple-mobile-web-app-status-bar-style" content="default">\
  <meta name="mobile-web-app-capable" content="yes">' build/web/index.html
fi

# Step 9: Generate bundle size report
echo "📊 Generating bundle size report..."
echo "Bundle Size Report" > build/web/bundle_report.txt
echo "==================" >> build/web/bundle_report.txt
echo "" >> build/web/bundle_report.txt

# Check sizes
for file in build/web/*.js build/web/*.css; do
  if [ -f "$file" ]; then
    size=$(du -h "$file" | cut -f1)
    filename=$(basename "$file")
    echo "$filename: $size" >> build/web/bundle_report.txt
  fi
done

echo "" >> build/web/bundle_report.txt
echo "Total size:" >> build/web/bundle_report.txt
du -sh build/web | cut -f1 >> build/web/bundle_report.txt

# Step 10: Create deployment-ready archive
echo "📦 Creating deployment archive..."
cd build/web
tar -czf ../gentlequest_web_optimized.tar.gz *
cd ../..

echo ""
echo "✅ Flutter Web PWA Optimization Complete!"
echo ""
echo "📊 Results:"
echo "  - Bundle location: build/web/"
echo "  - Deployment archive: build/gentlequest_web_optimized.tar.gz"
echo "  - Size report: build/web/bundle_report.txt"
echo ""
echo "🚀 Next steps:"
echo "  1. Deploy build/web/ contents to your web server"
echo "  2. Ensure HTTPS is enabled for PWA features"
echo "  3. Test offline functionality"
echo "  4. Verify PWA installation on mobile devices"
echo ""
echo "💡 Tips:"
echo "  - Install 'terser' for JS minification: npm install -g terser"
echo "  - Install 'csso' for CSS optimization: npm install -g csso-cli"
echo "  - Install 'imagemin' for image optimization: npm install -g imagemin-cli"
