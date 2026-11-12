import 'package:uuid/uuid.dart';

import 'secure_store.dart';

/// App-generated, random, resettable installation id. Hardware identifiers (IMEI, serial,
/// ICCID, ANDROID_ID) are never collected. This id is audit metadata only and is never used
/// for authentication or authorization. It is personal data: deleted on logout/clear data.
Future<String> installId() async {
  const key = 'acme.install_id';
  final existing = await secureStorage.read(key: key);
  if (existing != null) return existing;
  final id = const Uuid().v4(); // CSPRNG-backed
  await secureStorage.write(key: key, value: id);
  return id;
}
