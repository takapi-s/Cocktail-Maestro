import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

class ImageCropperWidget extends StatelessWidget {
  final XFile? pickedImage;
  final Function(XFile?) onImagePicked;
  final String fileId;

  const ImageCropperWidget({
    super.key,
    required this.pickedImage,
    required this.onImagePicked,
    required this.fileId,
  });

  Future<void> _pickAndCropImage(BuildContext context) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: image.path,
      aspectRatio: CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(toolbarTitle: '画像をトリミング', hideBottomControls: true),
        IOSUiSettings(title: '画像をトリミング'),
      ],
    );

    if (croppedFile != null) {
      onImagePicked(XFile(croppedFile.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _pickAndCropImage(context),
      child:
          pickedImage != null
              ? Image.file(File(pickedImage!.path), height: 200)
              : fileId.isNotEmpty
              ? CachedNetworkImage(
                imageUrl: "https://drive.google.com/uc?export=view&id=$fileId",
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder:
                    (context, url) =>
                        const Center(child: CircularProgressIndicator()),
                errorWidget: (context, url, error) => const Icon(Icons.error),
              )
              : Container(
                width: double.infinity,
                height: 200,
                color: Colors.grey,
                child: Icon(Icons.add_a_photo, size: 50),
              ),
    );
  }
}
