import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/shared/lost_ark_api/client/api_cooldown.dart';

void main() {
  test('shared server deadline keeps the later value without a client key', () {
    final now = DateTime.utc(2026, 10, 16);
    final cooldown = ApiCooldown(now: () => now);
    addTearDown(cooldown.dispose);
    cooldown.observe(now.add(const Duration(seconds: 30)));
    cooldown.observe(now.add(const Duration(seconds: 10)));
    expect(cooldown.seconds, 30);
  });
  test('expiry changes readiness without extending the server deadline', () {
    var now = DateTime.utc(2026, 10, 16);
    final cooldown = ApiCooldown(now: () => now);
    addTearDown(cooldown.dispose);
    final deadline = now.add(const Duration(seconds: 5));
    cooldown.observe(deadline);
    now = now.add(const Duration(seconds: 6));
    expect(cooldown.active, isFalse);
    expect(cooldown.until, deadline);
  });
}
