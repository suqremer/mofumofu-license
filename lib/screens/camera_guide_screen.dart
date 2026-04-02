import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';


/// ガイド付きカメラ画面
///
/// カメラプレビュー上に半透明のガイドオーバーレイを表示し、
/// ペットの顔を合わせて撮影できる。
class CameraGuideScreen extends StatefulWidget {
  const CameraGuideScreen({super.key});

  @override
  State<CameraGuideScreen> createState() => _CameraGuideScreenState();
}

class _CameraGuideScreenState extends State<CameraGuideScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  bool _isTakingPhoto = false;
  bool _isRearCamera = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _error = 'カメラが見つかりません');
        return;
      }
      await _setupCamera();
    } catch (e) {
      setState(() => _error = 'カメラの起動に失敗しました');
    }
  }

  Future<void> _setupCamera() async {
    final direction =
        _isRearCamera ? CameraLensDirection.back : CameraLensDirection.front;
    final camera = _cameras.firstWhere(
      (c) => c.lensDirection == direction,
      orElse: () => _cameras.first,
    );

    _controller?.dispose();
    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _controller = controller;
        _isInitialized = true;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = 'カメラの起動に失敗しました');
    }
  }

  Future<void> _toggleCamera() async {
    setState(() {
      _isRearCamera = !_isRearCamera;
      _isInitialized = false;
    });
    await _setupCamera();
  }

  Future<void> _takePhoto() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isTakingPhoto) {
      return;
    }

    setState(() => _isTakingPhoto = true);

    try {
      final xFile = await _controller!.takePicture();

      // 一時ディレクトリにコピー（image_pickerと同じパス体系）
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final savedPath = '${tempDir.path}/camera_guide_$timestamp.jpg';
      await File(xFile.path).copy(savedPath);

      if (!mounted) return;
      // 撮影した写真パスを返す
      context.pop(savedPath);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isTakingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('撮影に失敗しました。もう一度試してね'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // カメラプレビュー
          if (_isInitialized && _controller != null)
            _buildCameraPreview()
          else if (_error != null)
            Center(
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),

          // 上部バー
          _buildTopBar(),

          // 下部コントロール
          _buildBottomControls(),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    final controller = _controller!;
    final size = MediaQuery.of(context).size;
    final previewAspect = controller.value.aspectRatio;

    return Center(
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: size.width,
            height: size.width * previewAspect,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 閉じるボタン
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 48), // バランス用
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // カメラ切り替え
              IconButton(
                onPressed: _toggleCamera,
                icon: const Icon(
                  Icons.flip_camera_ios,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              // シャッターボタン
              GestureDetector(
                onTap: _takePhoto,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isTakingPhoto
                          ? Colors.grey
                          : Colors.white,
                    ),
                  ),
                ),
              ),
              // ダミー（バランス用）
              const SizedBox(width: 48),
            ],
          ),
        ),
      ),
    );
  }
}

