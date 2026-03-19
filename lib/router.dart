import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'screens/shell_screen.dart';
import 'screens/home_screen.dart';
import 'screens/collection_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/photo_select_screen.dart';
import 'screens/info_input_screen.dart';
import 'screens/frame_select_screen.dart';
import 'screens/preview_screen.dart';
import 'screens/mask_edit_screen.dart';
import 'screens/pet_notebook_screen.dart';
import 'screens/order_screen.dart';
import 'screens/order_card_screen.dart';
import 'screens/order_tag_screen.dart';
import 'screens/tag_design_screen.dart';
import 'screens/editor/photo_editor_screen.dart';
import 'screens/camera_guide_screen.dart';
import 'screens/nfc_write_screen.dart';
import 'screens/nfc_read_screen.dart';
import 'models/license_card.dart';

/// 作成フロー用のスライドアニメーション（右からスライドイン）
CustomTransitionPage<void> _slideTransition({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final tween = Tween(begin: const Offset(1, 0), end: Offset.zero)
          .chain(CurveTween(curve: Curves.easeInOut));
      return SlideTransition(position: animation.drive(tween), child: child);
    },
  );
}

/// フェードアニメーション（その他の画面遷移用）
CustomTransitionPage<void> _fadeTransition({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

/// アプリ全体のルーティング定義
final router = GoRouter(
  initialLocation: '/',
  routes: [
    // タブ付きシェル（ホーム・コレクション・設定）
    ShellRoute(
      builder: (context, state, child) => ShellScreen(child: child),
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/collection',
          builder: (context, state) => const CollectionScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    ),

    // 免許証作成フロー（タブなし、右からスライドイン）
    GoRoute(
      path: '/create/photo',
      pageBuilder: (context, state) =>
          _slideTransition(state: state, child: const PhotoSelectScreen()),
    ),
    GoRoute(
      path: '/create/info',
      pageBuilder: (context, state) =>
          _slideTransition(state: state, child: const InfoInputScreen()),
    ),
    GoRoute(
      path: '/create/frame',
      pageBuilder: (context, state) =>
          _slideTransition(state: state, child: const FrameSelectScreen()),
    ),
    GoRoute(
      path: '/create/mask',
      pageBuilder: (context, state) =>
          _slideTransition(state: state, child: const MaskEditScreen()),
    ),
    GoRoute(
      path: '/create/editor',
      pageBuilder: (context, state) =>
          _slideTransition(state: state, child: const PhotoEditorScreen()),
    ),
    GoRoute(
      path: '/create/preview',
      pageBuilder: (context, state) =>
          _slideTransition(state: state, child: const PreviewScreen()),
    ),
    GoRoute(
      path: '/create/camera',
      pageBuilder: (context, state) =>
          _slideTransition(state: state, child: const CameraGuideScreen()),
    ),

    // その他の画面（フェードイン）
    GoRoute(
      path: '/pet-notebook',
      pageBuilder: (context, state) =>
          _fadeTransition(state: state, child: const PetNotebookScreen()),
    ),
    GoRoute(
      path: '/order',
      pageBuilder: (context, state) =>
          _fadeTransition(state: state, child: const OrderScreen()),
    ),
    GoRoute(
      path: '/order/card',
      pageBuilder: (context, state) =>
          _slideTransition(state: state, child: const OrderCardScreen()),
    ),
    GoRoute(
      path: '/order/tag',
      pageBuilder: (context, state) =>
          _slideTransition(state: state, child: const OrderTagScreen()),
    ),
    GoRoute(
      path: '/order/set',
      pageBuilder: (context, state) =>
          _slideTransition(state: state, child: const OrderCardScreen(isSet: true)),
    ),
    GoRoute(
      path: '/order/tag-design',
      pageBuilder: (context, state) {
        final card = state.extra as LicenseCard;
        return _slideTransition(
          state: state,
          child: TagDesignScreen(card: card),
        );
      },
    ),
    GoRoute(
      path: '/nfc-write',
      pageBuilder: (context, state) {
        final card = state.extra as LicenseCard;
        return _fadeTransition(
          state: state,
          child: NfcWriteScreen(card: card),
        );
      },
    ),
    GoRoute(
      path: '/nfc-read',
      pageBuilder: (context, state) =>
          _fadeTransition(state: state, child: const NfcReadScreen()),
    ),
  ],
);
