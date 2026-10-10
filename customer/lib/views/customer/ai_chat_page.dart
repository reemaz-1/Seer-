import 'package:flutter/material.dart';

import '../../controllers/chat_controller.dart';
import '../../models/chat_message.dart';
import '../../theme/app_colors.dart';
import '../../widgets/chat_bubble.dart';
import '../../widgets/chat_input_bar.dart';
import 'dart:typed_data';
import '../../widgets/image_attach_button.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

///VIEW: the Ai assistant chat 
/// opened from the AI card in the homw page
class AiChatPage extends StatefulWidget {
  const AiChatPage({
    super.key,
    required this.uid,
    this.preferredVehicleId,
    this.controller,
  });

  final String uid;

  ///the vehicle the chat starts with (null = the customer's first vehicle)
  final String? preferredVehicleId;

  ///only for testing: pass chatController(assistant: FakeAiAssistant())
  ///to try thebpage without Gemini
  final ChatController? controller;


  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  late final ChatController _chat = widget.controller ?? 
    ChatController.forCustomer(
      uid: widget.uid,
      preferredVehicleId: widget.preferredVehicleId,
    );
  final _input = TextEditingController();
  final _scroll = ScrollController();
  // Temporarily store the selected image and its bytes before sending.
  XFile? _selectedImage;
Uint8List? _selectedImageBytes;
// Tracks whether the selected image was converted to JPEG.
bool _selectedImageWasConverted = false;

  ///example shown before the first message; tapping one sends it.
  static const _examples = [
    'السيارة ما تشتغل والأنوار ضعيفة',
    'كفري نزل وعندي سبير',
    'خلص البنزين والسيارة وقفت',
  ];

  @override
  void initState(){
    super.initState();
    //every change (a new message, or more words in the reply) scrolls down
    _chat.addListener(_scrollToBottom);
  }


  @override
  void dispose(){
     _chat.removeListener(_scrollToBottom);
     if (widget.controller == null) _chat.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }


/// Sends the customer's text and optional image to the AI assistant.
void _send(String text) {
  final message = text.trim();

  // Do not send an empty message unless an image is attached.
  if (_chat.isBusy || (message.isEmpty && _selectedImageBytes == null)) {
    return;
  }

  // Save the image data before clearing the preview.
  final imageBytes = _selectedImageBytes;

  // Determine the image MIME type required by Gemini.
  String imageMimeType = 'image/jpeg';

  // Compressed or converted images are always JPEG.
// Unprocessed PNG and WebP images keep their original format.
if (_selectedImage != null) {
  final extension = _selectedImage!.name.split('.').last.toLowerCase();

  if (extension == 'png' && !(_selectedImageWasConverted)) {
    imageMimeType = 'image/png';
  } else if (extension == 'webp' && !(_selectedImageWasConverted)) {
    imageMimeType = 'image/webp';
  }
}
  

  // Clear the text field and image preview after sending.
  _input.clear();

  setState(() {
    _selectedImage = null;
    _selectedImageBytes = null;
    _selectedImageWasConverted = false;
  });

  // Forward the message and image to the existing chat controller.
  _chat.send(
    message,
    imageBytes: imageBytes,
    imageMimeType: imageMimeType,
  );
}


/// Prepares a gallery or camera image for the AI assistant.
/// Converts supported image formats to JPEG and compresses large files.
Future<void> _onImageSelected(XFile image) async {
  try {
    final extension = image.name.split('.').last.toLowerCase();

    // Reject unsupported formats before processing.
    const supportedFormats = {
      'jpg', 'jpeg', 'png', 'webp', 'heic', 'heif',
    };

    if (!supportedFormats.contains(extension)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('نوع الصورة غير مدعوم')),
      );
      return;
    }

    // Convert the image to JPEG and reduce its size if necessary.
    Uint8List bytes = await image.readAsBytes();
    const maxSize = 7 * 1024 * 1024;
// Track whether compression changes the image format to JPEG.
bool wasConverted = false;
    if (extension == 'heic' ||
        extension == 'heif' ||
        bytes.length > maxSize) {
Uint8List compressed = bytes;

      for (final quality in [85, 65, 45, 25]) {
        compressed = await FlutterImageCompress.compressWithList(
          bytes,
          quality: quality,
          format: CompressFormat.jpeg,
        );

        if (compressed.length <= maxSize) break;
      }

      if (compressed.length > maxSize) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر تصغير الصورة إلى أقل من 7 ميجابايت'),
          ),
        );
        return;
      }

      bytes = compressed;
      wasConverted = true;
    }

    if (!mounted) return;

setState(() {
  _selectedImage = image;
  _selectedImageBytes = bytes;
  _selectedImageWasConverted = wasConverted;
});
  } catch (e) {
    debugPrint('Image processing failed: $e');

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تعذر معالجة الصورة، حاول مرة أخرى')),
    );
  }
}


  void _scrollToBottom(){
    WidgetsBinding.instance.addPostFrameCallback((_){
      if(!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _chat,
      builder: (context, _){
        return Scaffold(
          backgroundColor: CustomerColors.background,
          appBar: _appBar(),
          body: Column(
            children: [
              Expanded(
                child: _chat.messages.isEmpty ? _emptyState() : _messageList(),
              ),
              // Display a preview only when the user has selected an image.
              if (_selectedImageBytes != null)
  Padding(
    padding: const EdgeInsets.all(12),
    child: Align(
      alignment: Alignment.centerRight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              _selectedImageBytes!,
              width: 110,
              height: 110,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: -8,
            right: -8,
            child: IconButton.filled(
              tooltip: 'إزالة الصورة',
              icon: const Icon(Icons.close, size: 18),
              onPressed: () {
                setState(() {
                  _selectedImage = null;
                  _selectedImageBytes = null;
                });
              },
            ),
          ),
        ],
      ),
    ),
  ),
          ChatInputBar(
  controller: _input,
  enabled: !_chat.isBusy,
  onSend: _send,
  leading: ImageAttachButton(
    onImageSelected: _onImageSelected,
  ),
),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _appBar(){
    final vehicle = _chat.activeVehicle;
    return AppBar(
      backgroundColor: CustomerColors.darkPanel,
      foregroundColor: Colors.white,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text ('مساعد سير الذكي', style: TextStyle(fontSize: 17)),
          if (vehicle != null)
          Text(
            'المركبة: ${vehicle.title}',
            style: const TextStyle(fontSize: 12, color: CustomerColors.cardBorder),
          ),

        ],
      ),
      actions: [
        IconButton(
          tooltip: 'محادثة جديدة',
          icon: const Icon(Icons.refresh),
          onPressed: _chat.isBusy || _chat.messages.isEmpty ? null : _chat.reset,
        ),
      ],
    );
  }


  Widget _messageList() {
    final messages = _chat.messages;
    // While waiting for the first words, show a "typing" line at the end.
    final waiting = _chat.isBusy && messages.last.sender == ChatSender.customer;

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(12),
      itemCount: messages.length + (waiting ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == messages.length) return _typing();
        final message = messages[index];
        if (message.isSummary) return _summaryCard(message);
        return ChatBubble(message: message);
      },
    );
  }


  Widget _emptyState() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        const Icon(Icons.support_agent, size: 64, color: CustomerColors.accent),
        const SizedBox(height: 12),
        const Text(
          'وش المشكلة في سيارتك؟',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: CustomerColors.primaryText,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'اكتب المشكلة بكلماتك، وأساعدك تعرف الخدمة المناسبة وأرسل الطلب.',
          textAlign: TextAlign.center,
          style: TextStyle(color: CustomerColors.secondaryText),
        ),
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final example in _examples)
              ActionChip(
                label: Text(example),
                onPressed: _chat.isBusy ? null : () => _send(example),
              ),
          ],
        ),
      ],
    );
  }

  Widget _typing() {
    return const Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Text(
          'المساعد يكتب...',
          style: TextStyle(color: CustomerColors.secondaryText),
        ),
      ),
    );
  }



  

  /// TEMPORARY: piece 4 replaces this with the real summary card
  /// (map buttons, confirm button...). It only shows the data for now.
  Widget _summaryCard(ChatMessage message) {
    final s = message.summary!;
    final price = s.estimatedPrice == null
        ? 'غير محدد'
        : '${s.estimatedPrice} ريال${s.priceDependsOnDistance ? ' + حسب المسافة' : ''}';
    final status = switch (message.summaryState) {
      SummaryState.waiting => 'بانتظار تأكيدك',
      SummaryState.cancelled => 'أُلغي هذا الملخص',
      SummaryState.sent => 'تم إرسال الطلب',
    };

    return Opacity(
      opacity: message.summaryState == SummaryState.cancelled ? 0.5 : 1,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ملخص الطلب', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('المركبة: ${s.vehicle.title}'),
              Text('الخدمة: ${s.categoryLabel} - ${s.optionLabel}'),
              Text('السعر التقديري: $price'),
              if (s.note.isNotEmpty) Text('ملاحظة: ${s.note}'),
              if (s.missingLocationMessage != null)
                Text(s.missingLocationMessage!,
                    style: const TextStyle(color: AppStatusColors.warning)),
              const SizedBox(height: 6),
              Text(status, style: const TextStyle(color: CustomerColors.accent)),
            ],
          ),
        ),
      ),
    );
  }
}