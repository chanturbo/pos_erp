// ─────────────────────────────────────────
// Test Runner — รัน test ทั้งหมดในครั้งเดียว
// คำสั่ง: flutter test test/all_tests.dart
// ─────────────────────────────────────────

// Models
import 'models/product_model_test.dart'    as productModel;
import 'models/ap_invoice_model_test.dart' as apInvoiceModel;

// Utils
import 'utils/crypto_utils_test.dart'      as cryptoUtils;
import 'utils/responsive_utils_test.dart'  as responsiveUtils;

void main() {
  productModel.main();
  apInvoiceModel.main();
  cryptoUtils.main();
  responsiveUtils.main();
}