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
import 'screens/photo_editor_screen.dart';

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
  ],
);
