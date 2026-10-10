import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImageAttachButton extends StatelessWidget {
  const ImageAttachButton({
    super.key,
    required this.onImageSelected,
  });

  final ValueChanged<XFile> onImageSelected;

  Future<void> _pickImage(
    BuildContext context,
    ImageSource source,
  ) async {
    try {
      final image = await ImagePicker().pickImage(source: source);

      if (image != null) {
        onImageSelected(image);
      }
    } catch (e) {
      debugPrint('Image selection failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.add_photo_alternate_outlined),
      tooltip: 'إرفاق صورة',
      onPressed: () {
        showModalBottomSheet(
          context: context,
          builder: (sheetContext) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('اختيار من المعرض'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickImage(context, ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('التقاط صورة'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickImage(context, ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}