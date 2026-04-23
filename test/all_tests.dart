// ─────────────────────────────────────────
// Test Runner — รัน test ทั้งหมดในครั้งเดียว
// คำสั่ง: flutter test test/all_tests.dart
// ─────────────────────────────────────────

// Models
import 'models/product_model_test.dart'    as product_model;
import 'models/ap_invoice_model_test.dart' as ap_invoice_model;

// Utils
import 'utils/crypto_utils_test.dart'      as crypto_utils;
import 'utils/responsive_utils_test.dart'  as responsive_utils;

// Core Services
import 'core/services/offline_sync_service_test.dart' as offline_sync_service;
import 'features/restaurant/takeaway_flow_test.dart' as takeaway_flow;

void main() {
  product_model.main();
  ap_invoice_model.main();
  crypto_utils.main();
  responsive_utils.main();
  offline_sync_service.main();
  takeaway_flow.main();
}
