import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';

final offlineMapServiceProvider = Provider((ref) => OfflineMapService(ref));

class OfflineMapService {
  final Ref _ref;
  final Dio _dio = Dio();

  OfflineMapService(this._ref);

  Future<String> getLocalTilesPath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/map_data';
  }

  Future<void> downloadRegion(String regionName, String fileKey) async {
    // 1. Get pre-signed URL from backend
    final client = _ref.read(apiClientProvider).client;
    final urlResponse = await client.get('/storage/presigned-download', queryParameters: {
      'fileKey': fileKey,
    });
    
    final String downloadUrl = urlResponse.data['url'];

    final localPath = await getLocalTilesPath();
    final file = File('$localPath/$regionName.pmtiles');

    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }

    try {
      await _dio.download(
        downloadUrl,
        file.path,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            debugPrint('Downloading $regionName: ${(received / total * 100).toStringAsFixed(0)}%');
          }
        },
      );
      debugPrint('Download complete: ${file.path}');
    } catch (e) {
      debugPrint('Error downloading map: $e');
      rethrow;
    }
  }

  Future<bool> isMapDownloaded(String regionName) async {
    final localPath = await getLocalTilesPath();
    final file = File('$localPath/$regionName.pmtiles');
    return await file.exists();
  }
}
