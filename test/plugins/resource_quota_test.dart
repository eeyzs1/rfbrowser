// Covers acceptance criteria:
// - AC-P4-4-1: ResourceQuota rate limit — exceeding maxMessagesPerSecond
//   throws ResourceQuotaExceededError
// - AC-P4-4-2: ResourceQuota message size limit — args exceeding
//   maxMessageSizeBytes throws ResourceQuotaExceededError
// - AC-P4-4-3: ResourceQuota execution timeout — calls exceeding
//   maxExecutionDuration are terminated
// - AC-P4-4-4: ResourceQuota consecutive error limit — sandbox auto-stops
//   after maxConsecutiveErrors
// - AC-P4-4-5: ResourceQuota default values
import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/plugins/host/plugin_host.dart';

void main() {
  group('ResourceQuota defaults', () {
    test('defaultQuota has expected values', () {
      const quota = ResourceQuota.defaultQuota;
      expect(quota.maxMessagesPerSecond, 100);
      expect(quota.maxMessageSizeBytes, 1024 * 1024);
      expect(quota.maxExecutionDuration, const Duration(seconds: 30));
      expect(quota.maxConsecutiveErrors, 10);
    });

    test('custom quota preserves values', () {
      const quota = ResourceQuota(
        maxMessagesPerSecond: 50,
        maxMessageSizeBytes: 4096,
        maxExecutionDuration: Duration(seconds: 10),
        maxConsecutiveErrors: 5,
      );
      expect(quota.maxMessagesPerSecond, 50);
      expect(quota.maxMessageSizeBytes, 4096);
      expect(quota.maxExecutionDuration, const Duration(seconds: 10));
      expect(quota.maxConsecutiveErrors, 5);
    });

    test('zero maxMessagesPerSecond means no limit', () {
      const quota = ResourceQuota(maxMessagesPerSecond: 0);
      expect(quota.maxMessagesPerSecond, 0);
    });

    test('zero maxMessageSizeBytes means no limit', () {
      const quota = ResourceQuota(maxMessageSizeBytes: 0);
      expect(quota.maxMessageSizeBytes, 0);
    });

    test('zero maxConsecutiveErrors means no limit', () {
      const quota = ResourceQuota(maxConsecutiveErrors: 0);
      expect(quota.maxConsecutiveErrors, 0);
    });
  });

  group('ResourceQuota rate limit', () {
    test(
      'AC-P4-4-1: exceeding maxMessagesPerSecond throws ResourceQuotaExceededError',
      () async {
        final manifest = PluginManifest(
          id: 'rate-limit-plugin',
          name: 'Rate Limit Plugin',
          permissions: [Permission.knowledgeRead],
        );
        final sandbox = Sandbox(
          pluginId: manifest.id,
          manifest: manifest,
          apiHandler: (apiName, args) async => {'ok': true},
          quota: const ResourceQuota(
            maxMessagesPerSecond: 2,
            maxMessageSizeBytes: 0,
            maxExecutionDuration: Duration(seconds: 5),
            maxConsecutiveErrors: 0,
          ),
        );
        await sandbox.start();
        addTearDown(sandbox.stop);

        // First 2 calls should succeed
        final r1 = await sandbox.callApi<Map<String, dynamic>>(
          'knowledge.getNote',
          {'id': '1'},
          requiredPermission: Permission.knowledgeRead,
        );
        expect(r1, isNotNull);
        expect(r1!['ok'], true);

        final r2 = await sandbox.callApi<Map<String, dynamic>>(
          'knowledge.getNote',
          {'id': '2'},
          requiredPermission: Permission.knowledgeRead,
        );
        expect(r2, isNotNull);
        expect(r2!['ok'], true);

        // Third call should throw ResourceQuotaExceededError
        expect(
          () => sandbox.callApi('knowledge.getNote', {
            'id': '3',
          }, requiredPermission: Permission.knowledgeRead),
          throwsA(isA<ResourceQuotaExceededError>()),
        );
      },
    );

    test('rate limit error message contains the limit value', () async {
      final manifest = PluginManifest(
        id: 'rl-msg-plugin',
        name: 'RL Msg Plugin',
        permissions: [Permission.knowledgeRead],
      );
      final sandbox = Sandbox(
        pluginId: manifest.id,
        manifest: manifest,
        apiHandler: (apiName, args) async => {'ok': true},
        quota: const ResourceQuota(
          maxMessagesPerSecond: 1,
          maxMessageSizeBytes: 0,
          maxExecutionDuration: Duration(seconds: 5),
          maxConsecutiveErrors: 0,
        ),
      );
      await sandbox.start();
      addTearDown(sandbox.stop);

      // First call succeeds
      await sandbox.callApi<Map<String, dynamic>>('knowledge.getNote', {
        'id': '1',
      }, requiredPermission: Permission.knowledgeRead);

      // Second call throws
      try {
        await sandbox.callApi('knowledge.getNote', {
          'id': '2',
        }, requiredPermission: Permission.knowledgeRead);
        fail('Should have thrown ResourceQuotaExceededError');
      } on ResourceQuotaExceededError catch (e) {
        expect(e.message, contains('rate limit'));
        expect(e.message, contains('1'));
      }
    });

    test('zero maxMessagesPerSecond disables rate limiting', () async {
      final manifest = PluginManifest(
        id: 'no-rl-plugin',
        name: 'No RL Plugin',
        permissions: [Permission.knowledgeRead],
      );
      final sandbox = Sandbox(
        pluginId: manifest.id,
        manifest: manifest,
        apiHandler: (apiName, args) async => {'ok': true},
        quota: const ResourceQuota(
          maxMessagesPerSecond: 0,
          maxMessageSizeBytes: 0,
          maxExecutionDuration: Duration(seconds: 5),
          maxConsecutiveErrors: 0,
        ),
      );
      await sandbox.start();
      addTearDown(sandbox.stop);

      // Make many rapid calls — all should succeed
      for (int i = 0; i < 20; i++) {
        final result = await sandbox.callApi<Map<String, dynamic>>(
          'knowledge.getNote',
          {'id': '$i'},
          requiredPermission: Permission.knowledgeRead,
        );
        expect(result, isNotNull);
        expect(result!['ok'], true);
      }
    });
  });

  group('ResourceQuota message size limit', () {
    test(
      'AC-P4-4-2: args exceeding maxMessageSizeBytes throws ResourceQuotaExceededError',
      () async {
        final manifest = PluginManifest(
          id: 'msg-size-plugin',
          name: 'Msg Size Plugin',
          permissions: [Permission.knowledgeRead],
        );
        final sandbox = Sandbox(
          pluginId: manifest.id,
          manifest: manifest,
          apiHandler: (apiName, args) async => {'ok': true},
          quota: const ResourceQuota(
            maxMessagesPerSecond: 0,
            maxMessageSizeBytes: 100,
            maxExecutionDuration: Duration(seconds: 5),
            maxConsecutiveErrors: 0,
          ),
        );
        await sandbox.start();
        addTearDown(sandbox.stop);

        // Small args should succeed
        final smallResult = await sandbox.callApi<Map<String, dynamic>>(
          'knowledge.getNote',
          {'id': 'x'},
          requiredPermission: Permission.knowledgeRead,
        );
        expect(smallResult, isNotNull);

        // Large args should throw
        final bigArgs = {'data': 'x' * 200};
        expect(
          () => sandbox.callApi(
            'knowledge.getNote',
            bigArgs,
            requiredPermission: Permission.knowledgeRead,
          ),
          throwsA(isA<ResourceQuotaExceededError>()),
        );
      },
    );

    test('message size error contains size info', () async {
      final manifest = PluginManifest(
        id: 'msg-size-info',
        name: 'Msg Size Info',
        permissions: [Permission.knowledgeRead],
      );
      final sandbox = Sandbox(
        pluginId: manifest.id,
        manifest: manifest,
        apiHandler: (apiName, args) async => {'ok': true},
        quota: const ResourceQuota(
          maxMessagesPerSecond: 0,
          maxMessageSizeBytes: 50,
          maxExecutionDuration: Duration(seconds: 5),
          maxConsecutiveErrors: 0,
        ),
      );
      await sandbox.start();
      addTearDown(sandbox.stop);

      try {
        await sandbox.callApi('knowledge.getNote', {
          'data': 'x' * 100,
        }, requiredPermission: Permission.knowledgeRead);
        fail('Should have thrown ResourceQuotaExceededError');
      } on ResourceQuotaExceededError catch (e) {
        expect(e.message, contains('too large'));
        expect(e.message, contains('50'));
      }
    });

    test('zero maxMessageSizeBytes disables size limiting', () async {
      final manifest = PluginManifest(
        id: 'no-size-limit',
        name: 'No Size Limit',
        permissions: [Permission.knowledgeRead],
      );
      final sandbox = Sandbox(
        pluginId: manifest.id,
        manifest: manifest,
        apiHandler: (apiName, args) async => {'ok': true},
        quota: const ResourceQuota(
          maxMessagesPerSecond: 0,
          maxMessageSizeBytes: 0,
          maxExecutionDuration: Duration(seconds: 5),
          maxConsecutiveErrors: 0,
        ),
      );
      await sandbox.start();
      addTearDown(sandbox.stop);

      final bigArgs = {'data': 'x' * 10000};
      final result = await sandbox.callApi<Map<String, dynamic>>(
        'knowledge.getNote',
        bigArgs,
        requiredPermission: Permission.knowledgeRead,
      );
      expect(result, isNotNull);
      expect(result!['ok'], true);
    });
  });

  group('ResourceQuota execution timeout', () {
    test(
      'AC-P4-4-3: apiHandler exceeding maxExecutionDuration throws Exception',
      () async {
        final manifest = PluginManifest(
          id: 'timeout-plugin',
          name: 'Timeout Plugin',
          permissions: [Permission.knowledgeRead],
        );
        final sandbox = Sandbox(
          pluginId: manifest.id,
          manifest: manifest,
          apiHandler: (apiName, args) async {
            await Future.delayed(const Duration(milliseconds: 300));
            return {'ok': true};
          },
          quota: const ResourceQuota(
            maxMessagesPerSecond: 0,
            maxMessageSizeBytes: 0,
            maxExecutionDuration: Duration(milliseconds: 100),
            maxConsecutiveErrors: 0,
          ),
        );
        await sandbox.start();
        addTearDown(() async {
          await sandbox.stop();
          // Allow the pending apiHandler Future to settle
          await Future.delayed(const Duration(milliseconds: 400));
        });

        try {
          await sandbox.callApi('knowledge.getNote', {
            'id': 'x',
          }, requiredPermission: Permission.knowledgeRead);
          fail('Expected timeout exception');
        } catch (e) {
          expect(e, isA<Exception>());
          expect(e.toString(), contains('timeout'));
        }
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );

    test(
      'timeout does not auto-stop sandbox when maxConsecutiveErrors is 0',
      () async {
        final manifest = PluginManifest(
          id: 'timeout-no-stop',
          name: 'Timeout No Stop',
          permissions: [Permission.knowledgeRead],
        );
        final sandbox = Sandbox(
          pluginId: manifest.id,
          manifest: manifest,
          apiHandler: (apiName, args) async {
            await Future.delayed(const Duration(milliseconds: 300));
            return {'ok': true};
          },
          quota: const ResourceQuota(
            maxMessagesPerSecond: 0,
            maxMessageSizeBytes: 0,
            maxExecutionDuration: Duration(milliseconds: 100),
            maxConsecutiveErrors: 0,
          ),
        );
        await sandbox.start();
        addTearDown(() async {
          await sandbox.stop();
          await Future.delayed(const Duration(milliseconds: 400));
        });

        try {
          await sandbox.callApi('knowledge.getNote', {
            'id': 'x',
          }, requiredPermission: Permission.knowledgeRead);
          fail('Expected timeout exception');
        } catch (e) {
          // Sandbox should still be running because maxConsecutiveErrors is 0
          expect(sandbox.isRunning, isTrue);
        }
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );
  });

  group('ResourceQuota consecutive error limit', () {
    test(
      'AC-P4-4-4: sandbox auto-stops after maxConsecutiveErrors',
      () async {
        final manifest = PluginManifest(
          id: 'error-plugin',
          name: 'Error Plugin',
          permissions: [Permission.knowledgeRead],
        );
        final sandbox = Sandbox(
          pluginId: manifest.id,
          manifest: manifest,
          apiHandler: (apiName, args) async {
            throw Exception('API error');
          },
          quota: const ResourceQuota(
            maxMessagesPerSecond: 0,
            maxMessageSizeBytes: 0,
            maxExecutionDuration: Duration(seconds: 5),
            maxConsecutiveErrors: 3,
          ),
        );
        await sandbox.start();

        // First 2 calls should throw Exception but sandbox stays running
        for (int i = 0; i < 2; i++) {
          try {
            await sandbox.callApi('knowledge.getNote', {
              'id': '$i',
            }, requiredPermission: Permission.knowledgeRead);
            fail('Expected exception on call ${i + 1}');
          } catch (e) {
            expect(e, isA<Exception>());
            expect(e.toString(), contains('API error'));
          }
        }
        expect(sandbox.isRunning, isTrue);

        // Third call should throw Exception and trigger auto-stop
        try {
          await sandbox.callApi('knowledge.getNote', {
            'id': '2',
          }, requiredPermission: Permission.knowledgeRead);
          fail('Expected exception on call 3');
        } catch (e) {
          expect(e, isA<Exception>());
        }

        // Sandbox should be auto-stopped
        expect(sandbox.isRunning, isFalse);

        // Wait for async cleanup to settle
        await Future.delayed(const Duration(milliseconds: 200));
      },
      timeout: const Timeout(Duration(seconds: 15)),
    );

    test(
      'consecutive errors reset after a successful call',
      () async {
        final manifest = PluginManifest(
          id: 'reset-errors',
          name: 'Reset Errors',
          permissions: [Permission.knowledgeRead],
        );
        var shouldFail = true;
        final sandbox = Sandbox(
          pluginId: manifest.id,
          manifest: manifest,
          apiHandler: (apiName, args) async {
            if (shouldFail) {
              throw Exception('API error');
            }
            return {'ok': true};
          },
          quota: const ResourceQuota(
            maxMessagesPerSecond: 0,
            maxMessageSizeBytes: 0,
            maxExecutionDuration: Duration(seconds: 5),
            maxConsecutiveErrors: 3,
          ),
        );
        await sandbox.start();
        addTearDown(() async {
          await sandbox.stop();
          await Future.delayed(const Duration(milliseconds: 200));
        });

        // Two errors
        for (int i = 0; i < 2; i++) {
          try {
            await sandbox.callApi('knowledge.getNote', {
              'id': '$i',
            }, requiredPermission: Permission.knowledgeRead);
            fail('Expected exception');
          } catch (_) {}
        }
        expect(sandbox.isRunning, isTrue);

        // A successful call resets the counter
        shouldFail = false;
        final result = await sandbox.callApi<Map<String, dynamic>>(
          'knowledge.getNote',
          {'id': 'ok'},
          requiredPermission: Permission.knowledgeRead,
        );
        expect(result, isNotNull);
        expect(result!['ok'], true);

        // Two more errors should NOT auto-stop (counter was reset)
        shouldFail = true;
        for (int i = 0; i < 2; i++) {
          try {
            await sandbox.callApi('knowledge.getNote', {
              'id': '$i',
            }, requiredPermission: Permission.knowledgeRead);
            fail('Expected exception');
          } catch (_) {}
        }
        expect(sandbox.isRunning, isTrue);
      },
      timeout: const Timeout(Duration(seconds: 15)),
    );

    test(
      'zero maxConsecutiveErrors disables auto-stop',
      () async {
        final manifest = PluginManifest(
          id: 'no-auto-stop',
          name: 'No Auto Stop',
          permissions: [Permission.knowledgeRead],
        );
        final sandbox = Sandbox(
          pluginId: manifest.id,
          manifest: manifest,
          apiHandler: (apiName, args) async {
            throw Exception('API error');
          },
          quota: const ResourceQuota(
            maxMessagesPerSecond: 0,
            maxMessageSizeBytes: 0,
            maxExecutionDuration: Duration(seconds: 5),
            maxConsecutiveErrors: 0,
          ),
        );
        await sandbox.start();
        addTearDown(() async {
          await sandbox.stop();
          await Future.delayed(const Duration(milliseconds: 200));
        });

        // Many errors should not auto-stop
        for (int i = 0; i < 5; i++) {
          try {
            await sandbox.callApi('knowledge.getNote', {
              'id': '$i',
            }, requiredPermission: Permission.knowledgeRead);
            fail('Expected exception');
          } catch (_) {}
        }
        expect(sandbox.isRunning, isTrue);
      },
      timeout: const Timeout(Duration(seconds: 15)),
    );
  });
}
