import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yadyar_app/repositories/install_id_repository.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('generates a 32-character hex id and persists it', () async {
    final repository = InstallIdRepository();

    final id = await repository.getOrCreateId();

    expect(id, hasLength(32));
    expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(id), isTrue);
  });

  test('reuses the same id across repository instances (persisted)', () async {
    final first = await InstallIdRepository().getOrCreateId();
    final second = await InstallIdRepository().getOrCreateId();

    expect(second, first);
  });

  test('deduplicates concurrent calls to a single generation', () async {
    final repository = InstallIdRepository();

    final results = await Future.wait([
      repository.getOrCreateId(),
      repository.getOrCreateId(),
      repository.getOrCreateId(),
    ]);

    expect(results.toSet(), hasLength(1));
  });
}
