import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

class ImagePickerCropper extends StatefulWidget {
  final File? initialImage;
  final String? initialFileId; // ← 追加
  final void Function(File imageFile) onImageSelected;

  const ImagePickerCropper({
    super.key,
    required this.onImageSelected,
    this.initialImage,
    this.initialFileId, // ← 追加
  });

  @override
  State<ImagePickerCropper> createState() => _ImagePickerCropperState();
}

class _ImagePickerCropperState extends State<ImagePickerCropper> {
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    _imageFile = widget.initialImage;
  }

  Future<void> _pickImageWithCrop(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source);
    if (picked == null) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: '画像をトリミング',
          toolbarColor: Colors.teal,
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: true,
        ),
        IOSUiSettings(title: '画像をトリミング', aspectRatioLockEnabled: true),
      ],
    );

    if (cropped != null) {
      final file = File(cropped.path);
      setState(() {
        _imageFile = file;
      });
      widget.onImageSelected(file);
    }
  }

  void _showSourceSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('カメラで撮影'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageWithCrop(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('ギャラリーから選択'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageWithCrop(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasInitialNetworkImage =
        widget.initialFileId != null && _imageFile == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(
          child:
              _imageFile != null
                  ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      _imageFile!,
                      height: 200,
                      fit: BoxFit.contain,
                    ),
                  )
                  : hasInitialNetworkImage
                  ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      imageUrl:
                          'https://drive.google.com/uc?export=view&id=${widget.initialFileId}',
                      height: 200,
                      fit: BoxFit.contain,
                      placeholder:
                          (context, url) => const CircularProgressIndicator(),
                      errorWidget:
                          (context, url, error) => const Icon(Icons.error),
                    ),
                  )
                  : Container(
                    height: 200,
                    width: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(child: Text('画像が選択されていません')),
                  ),
        ),
        const SizedBox(height: 8),
        Center(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.image),
            label: const Text('画像を選択'),
            onPressed: _showSourceSelector,
          ),
        ),
      ],
    );
  }
}
