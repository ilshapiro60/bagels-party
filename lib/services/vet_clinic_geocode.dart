import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:geocoding/geocoding.dart' as geo;
import 'package:http/http.dart' as http;

/// Normalizes common US address patterns that confuse platform geocoders (e.g. iOS).
String normalizeAddressForGeocode(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return s;
  s = s.replaceAllMapped(RegExp(r'#\s*(\d+)'), (m) => ' Suite ${m[1]} ');
  s = s.replaceAll('#', ' ');
  return s.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Drops suite / unit / apt segments before the city (Google Maps often includes "#75").
String stripSecondaryAddressForGeocode(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return s;
  s = s.replaceAll(
    RegExp(
      r'\s+(?:Suite|Ste|Unit|Apt\.?|#\s*|No\.?)\s*[\w-]+(?=\s*,)',
      caseSensitive: false,
    ),
    '',
  );
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return s;
}

List<String> _distinctQueryVariants(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return [];
  final n = normalizeAddressForGeocode(t);
  final nStripped = stripSecondaryAddressForGeocode(n);
  final tStripped = stripSecondaryAddressForGeocode(t);
  final out = <String>[];
  void add(String x) {
    final v = x.trim();
    if (v.isNotEmpty && !out.contains(v)) out.add(v);
  }

  add(n);
  add(nStripped);
  add(t);
  add(tStripped);
  return out;
}

const _httpTimeout = Duration(seconds: 18);

/// Forward geocode: device APIs when available, then Nominatim, then Photon.
Future<({double lat, double lng})?> tryGeocodeVetAddress(String address) async {
  final variants = _distinctQueryVariants(address);
  if (variants.isEmpty) return null;

  if (!kIsWeb) {
    for (final q in variants) {
      try {
        final list = await geo.locationFromAddress(q);
        if (list.isNotEmpty) {
          final loc = list.first;
          return (lat: loc.latitude, lng: loc.longitude);
        }
      } catch (e, st) {
        debugPrint('vet_clinic_geocode native ($q): $e\n$st');
      }
    }
  }

  for (var i = 0; i < variants.length; i++) {
    if (i > 0) {
      await Future<void>.delayed(const Duration(milliseconds: 1100));
    }
    final r = await _nominatimGeocode(variants[i]);
    if (r != null) return r;
  }

  for (final q in variants) {
    final r = await _photonGeocode(q);
    if (r != null) return r;
  }

  return null;
}

/// OSM Nominatim — User-Agent must identify the app (see OSMF usage policy).
Future<({double lat, double lng})?> _nominatimGeocode(String query) async {
  try {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': query,
      'format': 'json',
      'limit': '1',
    });
    final resp = await http
        .get(
          uri,
          headers: {
            'User-Agent':
                'PawParty/1.0 (Flutter; vet clinic geocode; +https://pawparty.app)',
            'Accept-Language': 'en-US,en;q=0.9',
          },
        )
        .timeout(_httpTimeout);
    if (resp.statusCode != 200) {
      debugPrint('nominatim status ${resp.statusCode} body: ${resp.body}');
      return null;
    }
    final data = jsonDecode(resp.body);
    if (data is! List || data.isEmpty) return null;
    final first = data.first;
    if (first is! Map<String, dynamic>) return null;
    final lat = double.tryParse('${first['lat']}');
    final lon = double.tryParse('${first['lon']}');
    if (lat == null || lon == null) return null;
    return (lat: lat, lng: lon);
  } catch (e, st) {
    debugPrint('vet_clinic_geocode nominatim: $e\n$st');
    return null;
  }
}

/// Komoot Photon (OSM-based) — tolerant fallback, works when Nominatim is empty or blocked.
Future<({double lat, double lng})?> _photonGeocode(String query) async {
  try {
    final uri = Uri.https('photon.komoot.io', '/api/', {
      'q': query,
      'limit': '1',
    });
    final resp = await http
        .get(
          uri,
          headers: {
            'User-Agent': 'PawParty/1.0 (Flutter vet clinic lookup)',
            'Accept-Language': 'en',
          },
        )
        .timeout(_httpTimeout);
    if (resp.statusCode != 200) return null;
    final data = jsonDecode(resp.body);
    if (data is! Map<String, dynamic>) return null;
    final features = data['features'];
    if (features is! List || features.isEmpty) return null;
    final geom = (features.first as Map<String, dynamic>)['geometry'];
    if (geom is! Map<String, dynamic>) return null;
    final coords = geom['coordinates'];
    if (coords is! List || coords.length < 2) return null;
    final lon = double.tryParse('${coords[0]}');
    final lat = double.tryParse('${coords[1]}');
    if (lat == null || lon == null) return null;
    return (lat: lat, lng: lon);
  } catch (e, st) {
    debugPrint('vet_clinic_geocode photon: $e\n$st');
    return null;
  }
}
