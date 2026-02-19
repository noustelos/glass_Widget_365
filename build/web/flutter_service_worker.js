'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"version.json": "fed0dd5396fdc580cdd1011a510639e0",
"index.html": "2d6130fc55d37a8a7544b9322a09bb24",
"/": "2d6130fc55d37a8a7544b9322a09bb24",
"main.dart.js": "570ca302d92fde12d14d17bc034420e6",
"flutter.js": "7d69e653079438abfbb24b82a655b0a4",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"manifest.json": "5cd93bc9a01f21ccef820a0d9eb62a1f",
"assets/AssetManifest.json": "73877da57f5a546947eda4daf0062bf9",
"assets/NOTICES": "9c3cbf795653a6cb8c89f0d217c2f91f",
"assets/FontManifest.json": "b88bb5b6d1e5e62b39fb46e6f35f63fb",
"assets/AssetManifest.bin.json": "f733281e5c091d26c384969d21815293",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "e986ebe42ef785b27164c36a9abc7818",
"assets/shaders/ink_sparkle.frag": "4096b5150bac93c41cbc9b45276bd90f",
"assets/AssetManifest.bin": "5cf162756f39e10a69d92ff3a882aa6f",
"assets/fonts/MaterialIcons-Regular.otf": "de07f60e7d113cd47cb34baa8eed7e28",
"assets/data/march.json": "526e3e68702bad7af35b21b94ae18bc8",
"assets/data/november.json": "1fbc2571a94bfb623d77d7338fb78d10",
"assets/data/december.json": "cf6512d064e4607b1f802c8c8b0b4dcd",
"assets/data/may.json": "edbb8bdddbd3dca99a4bfe664eee31d0",
"assets/data/january.json": "ceaec9564d714169b5a1194a7616f489",
"assets/data/july.json": "49dba908f17b7470d0a34586b69c7396",
"assets/data/september.json": "b4afe96a58528795338bb91af0cd27dc",
"assets/data/october.json": "64e4e39a8fefaeba83bbb8bc1726899a",
"assets/data/extra_quotes.json": "93b0872e4b005f1e795fca99a30f65c4",
"assets/data/june.json": "043006fd5d47ca938899452967a9ef04",
"assets/data/february.json": "368670c0970337bb1641160b803d96bf",
"assets/data/august.json": "d1026e1ef4453851516948e31d75a249",
"assets/data/april.json": "31a0b2e2912d9be26bd8f6faaf765642",
"assets/assets/fonts/Montserrat-VariableFont_wght.ttf": "4d444017fdf9afc55059d7acb4c6c98f",
"assets/assets/fonts/GFSDidot-Regular.ttf": "116af4886b02077b6e648bd010c61f8a",
"assets/assets/data/march.json": "526e3e68702bad7af35b21b94ae18bc8",
"assets/assets/data/november.json": "1fbc2571a94bfb623d77d7338fb78d10",
"assets/assets/data/december.json": "cf6512d064e4607b1f802c8c8b0b4dcd",
"assets/assets/data/may.json": "edbb8bdddbd3dca99a4bfe664eee31d0",
"assets/assets/data/january.json": "ceaec9564d714169b5a1194a7616f489",
"assets/assets/data/july.json": "49dba908f17b7470d0a34586b69c7396",
"assets/assets/data/september.json": "b4afe96a58528795338bb91af0cd27dc",
"assets/assets/data/october.json": "64e4e39a8fefaeba83bbb8bc1726899a",
"assets/assets/data/extra_quotes.json": "93b0872e4b005f1e795fca99a30f65c4",
"assets/assets/data/june.json": "043006fd5d47ca938899452967a9ef04",
"assets/assets/data/february.json": "368670c0970337bb1641160b803d96bf",
"assets/assets/data/august.json": "d1026e1ef4453851516948e31d75a249",
"assets/assets/data/april.json": "31a0b2e2912d9be26bd8f6faaf765642",
"canvaskit/skwasm.js": "87063acf45c5e1ab9565dcf06b0c18b8",
"canvaskit/skwasm.wasm": "4124c42a73efa7eb886d3400a1ed7a06",
"canvaskit/chromium/canvaskit.js": "0ae8bbcc58155679458a0f7a00f66873",
"canvaskit/chromium/canvaskit.wasm": "f87e541501c96012c252942b6b75d1ea",
"canvaskit/canvaskit.js": "eb8797020acdbdf96a12fb0405582c1b",
"canvaskit/canvaskit.wasm": "64edb91684bdb3b879812ba2e48dd487",
"canvaskit/skwasm.worker.js": "bfb704a6c714a75da9ef320991e88b03"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"assets/AssetManifest.json",
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
