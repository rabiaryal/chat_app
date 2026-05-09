import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';

class ChatInput extends StatefulWidget {
  final Function(String) onSendMessage;

  const ChatInput({Key? key, required this.onSendMessage}) : super(key: key);

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSend() {
    if (_controller.text.trim().isNotEmpty) {
      widget.onSendMessage(_controller.text.trim());
      _controller.clear();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 1,
                      offset: const Offset(0, 1),
                    )
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: Icon(Icons.emoji_emotions_outlined, color: Colors.grey[600]),
                      onPressed: () {},
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        keyboardType: TextInputType.multiline,
                        maxLines: 5,
                        minLines: 1,
                        decoration: InputDecoration(
                          hintText: 'Message',
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                        ),
                        onChanged: (value) {
                          if (value.length == 1) {
                            context.read<ChatProvider>().onUserTyping();
                          }
                          setState(() {});
                        },
                      ),
                    ),
                    if (_controller.text.isEmpty)
                      IconButton(
                        icon: Icon(Icons.attach_file, color: Colors.grey[600]),
                        onPressed: () {},
                      ),
                    if (_controller.text.isEmpty)
                      IconButton(
                        icon: Icon(Icons.camera_alt, color: Colors.grey[600]),
                        onPressed: () {},
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: CircleAvatar(
                radius: 24,
                backgroundColor: Theme.of(context).primaryColor,
                child: IconButton(
                  icon: Icon(
                    _controller.text.isEmpty ? Icons.mic : Icons.send,
                    color: Colors.white,
                  ),
                  onPressed: _controller.text.isEmpty ? null : _handleSend,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
