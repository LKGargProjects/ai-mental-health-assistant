'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"flutter_bootstrap.js": "79488caffd0a9d3a4dd9df76afa2ef26",
"version.json": "ea37b9bbda27bdd97c20fb7bb3b83b4d",
"index.html": "bd186cb6edec7fd9ee93a858a30ce63a",
"/": "bd186cb6edec7fd9ee93a858a30ce63a",
"main.dart.js": "87f161299db772869f725acb26c10665",
"flutter.js": "83d881c1dbb6d6bcd6b42e274605b69c",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"manifest.json": "51365a6e4cb3ef76aa732b1a861526f7",
"assets/AssetManifest.json": "592600d4ea50f91f1023eeac95cae3ec",
"assets/NOTICES": "4874effe40e55a397a6d910b460833c5",
"assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"assets/AssetManifest.bin.json": "b6e98feb2fa3e746ea507e8e6515e70a",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/AssetManifest.bin": "f1fa2978210aaaec0c0da7ee6ae8cda4",
"assets/fonts/MaterialIcons-Regular.otf": "c8beb2991c77fd257b7238d55d83ab02",
"assets/assets/images/avatar_placeholder.png": "4d5bbf3e52203e7f5f1774e3b7ae71dd",
"assets/assets/images/background_placeholder.png": "b0d0260a5d6613b63ca49cc9ae8091f0",
"assets/assets/images/reference/Unknown-5.png": "11b7e4c83395e39f67577e0f8ff1ebe6",
"assets/assets/images/reference/Unknown-4.png": "f90d487ea4924013209762ea03ccfaca",
"assets/assets/images/reference/WelcomeScreen.png": "b0d0260a5d6613b63ca49cc9ae8091f0",
"assets/assets/images/reference/Unknown-6.png": "6ccb21622a995fd6e2f71c32b819fda1",
"assets/assets/images/reference/Unknown-12(1).png": "bdda30f1f63c5717f952927752499efc",
"assets/assets/images/reference/Unknown-7.png": "18c6539e5d618e0d1cc4c27c9e175c68",
"assets/assets/images/reference/Unknown-3.png": "cc3912f09364252cae477882496a4b74",
"assets/assets/images/reference/Unknown-26(635%2520x%25201440%2520px).png": "79a8bdb226e6906d1235f0184b12a09b",
"assets/assets/images/reference/Unknown-13.png": "ea0fa69600216c4f4e796a56c863970f",
"assets/assets/images/reference/Unknown-26(635%2520x%25201440%2520px).svg": "fc3216033c6249e4789536ffc484b3d2",
"assets/assets/images/reference/Unknown-11.png": "60214da43578216c36a244b5fe63f2f5",
"assets/assets/images/reference/Unknown-10.png": "3786cbe4021d683330efb12e94d0a9db",
"assets/assets/images/reference/Unknown-12(1)(635%2520x%25201440%2520px).png": "effd5b5f5a461e726e559fdce949208d",
"assets/assets/images/reference/Unknown-14.png": "934f4fbd27e8445b5a72680150c9c85d",
"assets/assets/images/reference/Unknown-28.png": "40cf5878fa17d397049fec777e20814a",
"assets/assets/images/reference/logo_placeholder.png": "a4d6a853c53e7ce9f5c194663c583749",
"assets/assets/images/reference/Unknown-29.png": "68b5b999ec114c63378b2f0c65d56c43",
"assets/assets/images/reference/Unknown-15.png": "e333c7527ed527806ce8d7610abb2dee",
"assets/assets/images/reference/WelcomeScreen.svg": "406d3678e3cfdd0b042f77ab523fa53a",
"assets/assets/images/reference/Unknown-17.png": "8732020a20489a1c2149073571ff9f40",
"assets/assets/images/reference/Unknown-16.png": "cca8f0214f9e565c041b3818853c4ada",
"assets/assets/images/reference/Unknown-27.png": "033bc69db28a1fd7e2d482b31fe27d98",
"assets/assets/images/reference/Unknown-26.png": "c6b94a4ce79bfd7b4b73b9a5b8f74481",
"assets/assets/images/reference/Unknown-18.png": "4944c17cff946d5c48877c75bea255f2",
"assets/assets/images/reference/Unknown-24.png": "066e0d9f900fef655f44dddee69c5e92",
"assets/assets/images/reference/Unknown-30.png": "c22f0c5b72ca6ebb5fc0e4be0ea6d092",
"assets/assets/images/reference/Unknown-31.png": "2d3029ef36d2874d6cf020204a614539",
"assets/assets/images/reference/Unknown-25.png": "9727d48cda711da0b5ee3724893a3960",
"assets/assets/images/reference/Unknown-21.png": "919173db43fcb7268d4ec8db0df9b064",
"assets/assets/images/reference/Unknown-20.png": "7512a56a30ff09510f5e78aa81bd83b6",
"assets/assets/images/reference/Unknown-22.png": "977ed7d1d8bea9973e11b673ed2ac9f1",
"assets/assets/images/reference/Unknown-23.png": "e9d63aa7016fbdc7d39e9ccace2166e4",
"assets/assets/images/reference/Unknown-19(1).png": "b91fe3f55ac2dc97fd2aa540588e382f",
"assets/assets/images/reference/Unknown-24(635%2520x%25201440%2520px).png": "57ae8b7834d0e635747bb1396b535bb9",
"assets/assets/images/reference/Unknown-9.png": "217b53fd32d6e47ee4225eac2fd5e6d9",
"assets/assets/images/reference/Layout%2520v1.pdf": "a97ee71cb1170cd116630cd5d13242e7",
"assets/assets/images/reference/Unknown-8.png": "22a20e5f6cb98466be17c635cff37c57",
"canvaskit/skwasm.js": "ea559890a088fe28b4ddf70e17e60052",
"canvaskit/skwasm.js.symbols": "e72c79950c8a8483d826a7f0560573a1",
"canvaskit/canvaskit.js.symbols": "bdcd3835edf8586b6d6edfce8749fb77",
"canvaskit/skwasm.wasm": "39dd80367a4e71582d234948adc521c0",
"canvaskit/chromium/canvaskit.js.symbols": "b61b5f4673c9698029fa0a746a9ad581",
"canvaskit/chromium/canvaskit.js": "8191e843020c832c9cf8852a4b909d4c",
"canvaskit/chromium/canvaskit.wasm": "f504de372e31c8031018a9ec0a9ef5f0",
"canvaskit/canvaskit.js": "728b2d477d9b8c14593d4f9b82b484f3",
"canvaskit/canvaskit.wasm": "7a3f4ae7d65fc1de6a6e7ddd3224bc93"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
