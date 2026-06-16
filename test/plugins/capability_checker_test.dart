import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/plugins/host/plugin_host.dart';
import 'package:rfbrowser/plugins/host/capability_checker.dart';

void main() {
  group('CapabilityChecker (G14-A)', () {
    PluginManifest makeManifest(List<Permission> perms) => PluginManifest(
      id: 'test.plugin',
      name: 'Test Plugin',
      version: '1.0.0',
      permissions: perms,
    );

    test('hasCapability returns true only for granted permissions', () {
      final m = makeManifest([Permission.knowledgeRead]);
      final c = CapabilityChecker(pluginId: 'p1', manifest: m);

      expect(c.hasCapability(Permission.knowledgeRead), isTrue);
      expect(c.hasCapability(Permission.knowledgeWrite), isFalse);
      expect(c.hasCapability(Permission.browserRead), isFalse);
      expect(c.hasCapability(Permission.aiChat), isFalse);
    });

    test('assertCapability succeeds when permission is granted', () {
      final c = CapabilityChecker(
        pluginId: 'p1',
        manifest: makeManifest([Permission.knowledgeRead, Permission.aiChat]),
      );

      expect(
        () => c.assertCapability(Permission.knowledgeRead),
        returnsNormally,
      );
      expect(() => c.assertCapability(Permission.aiChat), returnsNormally);
    });

    test(
      'assertCapability throws PluginCapabilityDeniedError when missing',
      () {
        final c = CapabilityChecker(
          pluginId: 'p1',
          manifest: makeManifest([Permission.knowledgeRead]),
        );

        expect(
          () => c.assertCapability(Permission.knowledgeWrite),
          throwsA(
            isA<PluginCapabilityDeniedError>()
                .having((e) => e.pluginId, 'pluginId', 'p1')
                .having(
                  (e) => e.permission,
                  'permission',
                  Permission.knowledgeWrite,
                ),
          ),
        );
      },
    );

    test('assertAllCapabilities throws on first missing permission', () {
      final c = CapabilityChecker(
        pluginId: 'p2',
        manifest: makeManifest([Permission.knowledgeRead]),
      );

      expect(
        () => c.assertAllCapabilities([
          Permission.knowledgeRead,
          Permission.knowledgeWrite,
        ]),
        throwsA(isA<PluginCapabilityDeniedError>()),
      );
    });

    test(
      'assertAnyCapability throws when none of the alternatives is granted',
      () {
        final c = CapabilityChecker(
          pluginId: 'p3',
          manifest: makeManifest([Permission.browserRead]),
        );

        expect(
          () => c.assertAnyCapability([
            Permission.knowledgeWrite,
            Permission.browserWrite,
          ]),
          throwsA(isA<PluginCapabilityDeniedError>()),
        );
      },
    );

    test('assertAnyCapability succeeds when at least one is granted', () {
      final c = CapabilityChecker(
        pluginId: 'p4',
        manifest: makeManifest([Permission.aiChat]),
      );

      expect(
        () => c.assertAnyCapability([Permission.aiChat, Permission.uiCommand]),
        returnsNormally,
      );
    });

    test('empty permission list means the plugin has no capabilities', () {
      final c = CapabilityChecker(
        pluginId: 'p5',
        manifest: makeManifest(const []),
      );

      for (final p in Permission.values) {
        expect(c.hasCapability(p), isFalse);
      }
    });

    test('CapabilityMatrix exposes stable constants', () {
      expect(CapabilityMatrix.knowledgeRead, Permission.knowledgeRead);
      expect(CapabilityMatrix.knowledgeWrite, Permission.knowledgeWrite);
      expect(CapabilityMatrix.browserRead, Permission.browserRead);
      expect(CapabilityMatrix.browserWrite, Permission.browserWrite);
      expect(CapabilityMatrix.aiChat, Permission.aiChat);
      expect(CapabilityMatrix.uiCommand, Permission.uiCommand);
      expect(CapabilityMatrix.uiPanel, Permission.uiPanel);
    });
  });

  group('PluginManifest permissions (G14-A)', () {
    test('round-trip through toMap/fromMap preserves all permissions', () {
      final original = PluginManifest(
        id: 'round.trip',
        name: 'Round Trip',
        version: '1.0.0',
        permissions: [
          Permission.knowledgeRead,
          Permission.knowledgeWrite,
          Permission.aiChat,
          Permission.uiCommand,
        ],
      );

      final restored = PluginManifest.fromMap(original.toMap());

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.permissions, original.permissions);
    });

    test('unknown permission names fall back to knowledgeRead', () {
      final m = PluginManifest.fromMap({
        'id': 'p',
        'name': 'P',
        'permissions': ['nonexistent', Permission.aiChat.name],
      });

      expect(m.permissions, contains(Permission.aiChat));
      expect(m.permissions, contains(Permission.knowledgeRead));
    });
  });
}
