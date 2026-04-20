import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../../services/license/license_local_service.dart';
import '../../services/license/license_models.dart';

Middleware licenseMiddleware() {
  return (Handler handler) {
    return (Request request) async {
      if (_isSafeMethod(request.method)) {
        return handler(request);
      }

      final feature = _featureForRequest(request);
      if (feature == null) {
        return handler(request);
      }

      try {
        await LicenseLocalService.ensureFeatureAllowed(feature);
        return handler(request);
      } on LicenseRestrictionException catch (error) {
        return Response(
          403,
          body: jsonEncode({
            'success': false,
            'code': 'LICENSE_REQUIRED',
            'feature': feature.name,
            'message': error.message,
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }
    };
  };
}

bool _isSafeMethod(String method) =>
    method == 'GET' || method == 'HEAD' || method == 'OPTIONS';

LicenseFeature? _featureForRequest(Request request) {
  final path = request.url.path;

  if (path.startsWith('api/auth') ||
      path == 'api/health' ||
      path.startsWith('api/reports') ||
      path.startsWith('api/sync')) {
    return null;
  }

  if (path.startsWith('api/sales')) {
    return LicenseFeature.openSale;
  }

  return LicenseFeature.createEdit;
}
