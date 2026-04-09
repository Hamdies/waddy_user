import re

with open('lib/features/places/screens/place_details_screen.dart', 'r') as f:
    code = f.read()

# 1. Less neo
code = code.replace('const _kBw = 4.0;', 'const _kBw = 2.0;')
code = code.replace('const _kShad = BoxShadow(color: Colors.black, offset: Offset(8, 8), blurRadius: 0);', 'const _kShad = BoxShadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 0);')

# 2. Replace WADDI 80 with PLACE DETAILS
appbar_title_old = """        title: Row(
          children: [
            Text(
              'WADDI',
              style: robotoBlack.copyWith(
                color: Colors.black,
                fontStyle: FontStyle.italic,
                fontSize: 24,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              color: Colors.green,
              child: Text(
                '80',
                style: robotoBlack.copyWith(color: Colors.black, fontSize: 12),
              ),
            ),
          ],
        ),"""
appbar_title_new = """        title: Text(
          'PLACE DETAILS',
          style: robotoBlack.copyWith(
            color: Colors.black,
            fontSize: 18,
            letterSpacing: 1,
          ),
        ),"""
if appbar_title_old in code:
    code = code.replace(appbar_title_old, appbar_title_new)

# 3. Format Votes
votes_old = """'${(place.votesCount / 1000).toStringAsFixed(1)}K VOTES'"""
votes_new = """'${place.votesCount >= 1000 ? (place.votesCount / 1000).toStringAsFixed(1) + 'K' : place.votesCount} VOTES'"""
code = code.replace(votes_old, votes_new)

# 4. Fix overflow
overflow_old = """            Text(
              place.address?.toUpperCase() ?? 'UNKNOWN LOCATION',
              style: robotoBold.copyWith(fontSize: 12, color: Colors.black),
            ),"""
overflow_new = """            Expanded(
              child: Text(
                place.address?.toUpperCase() ?? 'UNKNOWN LOCATION',
                style: robotoBold.copyWith(fontSize: 12, color: Colors.black),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),"""
code = code.replace(overflow_old, overflow_new)

# 5. Fix Site, Instagram, Tiktok, Facebook
actions_old = """        Expanded(
          child: GestureDetector(
            onTap: () {
              if (place.website != null) {
                launchUrl(Uri.parse(place.website!), mode: LaunchMode.externalApplication);
              }
            },
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black, width: _kBw),
                boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(4, 4))],
              ),
              child: Center(
                child: Text(
                  'VISIT WEBSITE',
                  style: robotoBlack.copyWith(fontSize: 12, color: Colors.black),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        _sqBtn(Icons.camera_alt_outlined, () {
          if (place.instagram != null) {
            launchUrl(Uri.parse('https://instagram.com/${place.instagram}'), mode: LaunchMode.externalApplication);
          }
        }),
        const SizedBox(width: 12),
        _sqBtn(Icons.close, () {}),"""

actions_new = """        Expanded(
          child: GestureDetector(
            onTap: () {
              if (place.website != null) {
                launchUrl(Uri.parse(place.website!), mode: LaunchMode.externalApplication);
              }
            },
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black, width: _kBw),
                boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(3, 3))],
              ),
              child: Center(
                child: Text(
                  'VISIT WEBSITE',
                  style: robotoBlack.copyWith(fontSize: 12, color: Colors.black),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _sqBtn(Icons.camera_alt_outlined, () {
          if (place.instagram != null) {
            launchUrl(Uri.parse('https://instagram.com/${place.instagram}'), mode: LaunchMode.externalApplication);
          }
        }),
        const SizedBox(width: 8),
        _sqBtn(Icons.facebook_outlined, () {}), // Add proper facebook url if available
        const SizedBox(width: 8),
        _sqBtn(Icons.tiktok_outlined, () {}), // Add proper tiktok url if available"""
actions_new = actions_new.replace("Icons.tiktok_outlined", "Icons.music_video") # flutter built in map for tiktok icon is absent or alternative

code = code.replace(actions_old, actions_new)

# 6. Real Coordinates! (Google Maps)
google_map_import = """import 'package:google_maps_flutter/google_maps_flutter.dart';\n"""
if google_map_import not in code:
    code = code.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\n" + google_map_import)

coords_old = """    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'THE COORDINATES',
          style: robotoBlack.copyWith(fontSize: 16, color: Colors.black),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          height: 160,
          decoration: BoxDecoration(
            color: Colors.grey[800],
            border: Border.all(color: Colors.black, width: _kBw),
            boxShadow: const [_kShad],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Generic map bg
              Opacity(
                opacity: 0.5,
                child: Image.asset('assets/image/map_bg.png', fit: BoxFit.cover, errorBuilder: (_,__,___) => const SizedBox()),
              ),
              Center(
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    border: Border.all(color: const Color(0xFF00FFA3), width: 3),
                  ),
                  child: const Icon(Icons.my_location, color: Color(0xFF00FFA3)),
                ),
              ),
            ],
          ),
        ),
      ],
    );"""

coords_new = """    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'THE COORDINATES',
          style: robotoBlack.copyWith(fontSize: 16, color: Colors.black),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          height: 160,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            border: Border.all(color: Colors.black, width: _kBw),
            boxShadow: const [_kShad],
          ),
          child: place.lat != null && place.lng != null
              ? ClipRRect(
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(place.lat!, place.lng!),
                      zoom: 15,
                    ),
                    zoomControlsEnabled: false,
                    scrollGesturesEnabled: false,
                    markers: {
                      Marker(
                        markerId: const MarkerId('place_marker'),
                        position: LatLng(place.lat!, place.lng!),
                      ),
                    },
                  ),
                )
              : const Center(child: Text("Location unavailable")),
        ),
      ],
    );"""
code = code.replace(coords_old, coords_new)

# Update action button shadow references
code = code.replace('Offset(4, 4)', 'Offset(3, 3)')

with open('lib/features/places/screens/place_details_screen.dart', 'w') as f:
    f.write(code)
