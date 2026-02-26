class AppConfig {
  static const appName = 'POS + ERP System';
  static const appVersion = '1.0.0';
  
  // Server
  static const defaultServerPort = 8080;
  static const webSocketPath = '/ws';
  
  // Database
  static const databaseName = 'pos_erp.db';
  static const databaseVersion = 1;
  
  // Pagination
  static const defaultPageSize = 20;
  
  // Session
  static const sessionTimeout = Duration(hours: 8);
}