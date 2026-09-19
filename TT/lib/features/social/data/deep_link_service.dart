import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final deepLinkServiceProvider = Provider((ref) => DeepLinkService());

class DeepLinkService {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  final StreamController<Uri> _uriController = StreamController.broadcast();

  Stream<Uri> get uriStream => _uriController.stream;

  void initDeepLinks() {
    _appLinks = AppLinks();

    // Check initial link
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        _uriController.add(uri);
      }
    });

    // Handle link when app is in warm state
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _uriController.add(uri);
    });
  }

  void dispose() {
    _linkSubscription?.cancel();
    _uriController.close();
  }
}
