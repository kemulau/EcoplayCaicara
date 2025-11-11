'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"assets/AssetManifest.bin": "f151ef4ba553b349a8406ee6e1701945",
"assets/AssetManifest.bin.json": "31ab2a51a262276777b0180d98478f64",
"assets/AssetManifest.json": "6946f6599a0e95bdb6e687f55c78549e",
"assets/assets/audio/+fimdejogo.mp3": "6d7849108cf131c736685830cfc6a567",
"assets/assets/audio/-fimdejogo.mp3": "22be1c1377beac5cfe5540dfa7832431",
"assets/assets/audio/crabs-walking-sound-effect.mp3": "3ca61fffda022a4dfeadf60930cedcae",
"assets/assets/audio/negative-point.mp3": "eae0cfc6c4ba663cc82bcb5f29c87bc0",
"assets/assets/audio/page-flip-47177.mp3": "d22ccac44f9e5ec3b0a16bf9771861fe",
"assets/assets/audio/point-effect.wav": "be55c0d06768ffd9bdb2c8931674ccdf",
"assets/assets/audio/residuos-effect.wav": "e68aa161388b14647d4d4737f517aff5",
"assets/assets/audio/tech-ui-typing-30790.mp3": "f5330b0e061b7c25b88f0b5088d694cb",
"assets/assets/avatares/1.png": "67c82297dba4b561627d27d569d39659",
"assets/assets/avatares/2.png": "c789fbb9d0daa88733762470a8ae45c3",
"assets/assets/avatares/3.png": "d66a7e1ea095b71c5b41043bf70e5b94",
"assets/assets/avatares/caranguejo-uca.png": "81970e22da3d90a652f9dad9724d8267",
"assets/assets/avatares/guara-vermelho.png": "9aa6c323f0f531a4e1a9b6e42220a0b6",
"assets/assets/avatares/jaguatirica.png": "1410a6e42a6699684e03c069f0225538",
"assets/assets/cards/mare-responsa.jpg": "facc44e6ed2f5619b23ba2b7616963fc",
"assets/assets/cards/missao-reciclar.jpg": "86cae78c731bdccf521ce70a33818e6a",
"assets/assets/cards/moldura.png": "86ac8a7af7ef975c90e8925d1702c996",
"assets/assets/cards/toca-do-caranguejo.jpg": "bb297cf6e93530b765d9f44325854cd9",
"assets/assets/cards/trilha-da-fauna.jpg": "af511e7aae5ae6666acf4f64a890a8ee",
"assets/assets/fonts/Ldfcomicsans-jj7l.ttf": "847a306030a53f6399592d10c679b8e4",
"assets/assets/fonts/Ldfcomicsansbold-zgma.ttf": "be52e4de7e5d62de5e40f5ec1e5b5922",
"assets/assets/fonts/Ldfcomicsanshairline-5PmL.ttf": "fecb924c2132c11d4e09332e9943d2fa",
"assets/assets/fonts/Ldfcomicsanslight-6dZo.ttf": "e97d16602e3babe4f6c322dbf33a115e",
"assets/assets/fonts/OpenDyslexic-Bold-Italic.otf": "973e4f4098c9cbf26ad3f03e9345b200",
"assets/assets/fonts/OpenDyslexic-Bold.otf": "e3c427f3b9acc67a60085cdbcf4cc087",
"assets/assets/fonts/OpenDyslexic-Regular.otf": "57618c912a50080a2dd15770753b535a",
"assets/assets/fonts/PressStart2P-Regular.ttf": "ccb1dfce06ad3883f8e3b5ae011aa795",
"assets/assets/games/toca-do-caranguejo/acertou.png": "38395ca83545972490c788b6422dafae",
"assets/assets/games/toca-do-caranguejo/background-mobile.png": "203e47b91045d6475a11f5ec62d39e6c",
"assets/assets/games/toca-do-caranguejo/background.png": "8a70daad4e782211a849465792ba6809",
"assets/assets/games/toca-do-caranguejo/caranguejo.png": "8109d2e1fcae287754f7a4785bc7e327",
"assets/assets/games/toca-do-caranguejo/cordas.png": "673992d6dea7c19e0497c1715e4b723b",
"assets/assets/games/toca-do-caranguejo/lata.png": "12b2b1b9ed354a929d516dc3e79483e7",
"assets/assets/games/toca-do-caranguejo/mercado-loja.png": "2cf474fdefbc3971599c32972c949cbe",
"assets/assets/games/toca-do-caranguejo/pergaminho-aberto-3.png": "17058acb3e3a8ad8a035c6950712e667",
"assets/assets/games/toca-do-caranguejo/pergaminho-entreaberto-2.png": "a22bf7d9eeb9ff4327a67c94fad95d61",
"assets/assets/games/toca-do-caranguejo/pergaminho-fechado-1.png": "3c64cb935d277906e43eb2bd8fed70b9",
"assets/assets/games/toca-do-caranguejo/pet-sob-areia.png": "725d6efde38106b09edad64f1f8d3433",
"assets/assets/games/toca-do-caranguejo/residuo-caixa.png": "f87ad14970ee160ea351d3d34e1b98e8",
"assets/assets/games/toca-do-caranguejo/residuo-fralda-submersa.png": "b2aa96fa1a71bc17f12dfa73548f2027",
"assets/assets/games/toca-do-caranguejo/residuo-isopor-boiando.png": "1260c474a506a98b30cfa328aee02303",
"assets/assets/games/toca-do-caranguejo/residuo-madeira-musgo.png": "ccd9ebc5b9d6e05fb23bc1dcfb2ff19a",
"assets/assets/games/toca-do-caranguejo/sacola-submersa.png": "e56912a2ec00e0e622dfb83ee09f2218",
"assets/assets/images/background-toca-mobile.png": "0b4396b03e98e6d674a9655d7c32a7da",
"assets/assets/images/background-toca.png": "bcd49511a1d498b648ed3d9343b9df53",
"assets/assets/images/background.png": "1b5ae2d47f63882316988658c7410c5b",
"assets/FontManifest.json": "c278af8cca936559c9ea8a4c155dc350",
"assets/fonts/MaterialIcons-Regular.otf": "1747ff0b9631dc54b70011dfaeeab8f6",
"assets/NOTICES": "35b63b19e5871639aa0f04e0ba063dd2",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"canvaskit/canvaskit.js": "140ccb7d34d0a55065fbd422b843add6",
"canvaskit/canvaskit.js.symbols": "58832fbed59e00d2190aa295c4d70360",
"canvaskit/canvaskit.wasm": "07b9f5853202304d3b0749d9306573cc",
"canvaskit/chromium/canvaskit.js": "5e27aae346eee469027c80af0751d53d",
"canvaskit/chromium/canvaskit.js.symbols": "193deaca1a1424049326d4a91ad1d88d",
"canvaskit/chromium/canvaskit.wasm": "24c77e750a7fa6d474198905249ff506",
"canvaskit/skwasm.js": "1ef3ea3a0fec4569e5d531da25f34095",
"canvaskit/skwasm.js.symbols": "0088242d10d7e7d6d2649d1fe1bda7c1",
"canvaskit/skwasm.wasm": "264db41426307cfc7fa44b95a7772109",
"canvaskit/skwasm_heavy.js": "413f5b2b2d9345f37de148e2544f584f",
"canvaskit/skwasm_heavy.js.symbols": "3c01ec03b5de6d62c34e17014d1decd3",
"canvaskit/skwasm_heavy.wasm": "8034ad26ba2485dab2fd49bdd786837b",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"flutter.js": "888483df48293866f9f41d3d9274a779",
"flutter_bootstrap.js": "6bf5121f1cccdeea5f9f5d8569b2c7d6",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"index.html": "fe4045edb5c2497f2f759a7ad2a85210",
"/": "fe4045edb5c2497f2f759a7ad2a85210",
"main.dart.js": "4e634a434065594185698dca1c64ea2a",
"main.dart.js_1.part.js": "f29b6da389fb0fd0e1a39488c1c4f7af",
"main.dart.js_2.part.js": "270ab19baa3b8505a171840c9e090bb3",
"main.dart.js_3.part.js": "cbcf7e0f4639e07cda63b56c3b9c2067",
"manifest.json": "9c06ccdd02607be32cee1ec128ac7edf",
"version.json": "40ab7ce78204d2fcbf63a80f79915884"};
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
