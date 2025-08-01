import 'package:finmanager/Screens/config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage({required this.text, required this.isUser});
}

class AiAgentScreen extends StatefulWidget {
  final String userId;
  const AiAgentScreen({super.key, required this.userId});

  @override
  State<AiAgentScreen> createState() => _AiAgentScreenState();
}

class _AiAgentScreenState extends State<AiAgentScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  bool _speechEnabled = false;
  bool _isListening = false;

  final List<String> _examplePrompts = [
    "How much did I spend on Food this month?",
    "What was my biggest expense in August?",
    "Add a 500 rupee expense for a movie ticket",
  ];

  @override
  void initState() {
    super.initState();
    _messages.add(ChatMessage(text: "Hello! How can I help you with your finances today? You can ask me to find or add transactions.", isUser: false));
    _initSpeech();
  }
  
  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  void _startListening() async {
    await _speechToText.listen(
      onResult: (result) {
        setState(() => _controller.text = result.recognizedWords);
        if (result.finalResult) _sendMessage();
      },
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
    );
    setState(() => _isListening = true);
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() => _isListening = false);
  }

  Future<void> _speak(String text) async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.speak(text);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage({String? text}) async {
    final messageText = text ?? _controller.text;
    if (messageText.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: messageText, isUser: true));
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    // !! CRITICAL !!
    // Replace with your computer's local network IP address.
    const String apiUrl = AppConfig.aiAgentEndpoint; // <-- Example IP

    // --- THIS IS THE CRUCIAL PART THAT FIXES THE ERROR ---
    // We get the user's current local date and time.
    final String currentDate = DateTime.now().toIso8601String();

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        // The body MUST contain all three keys.
        body: jsonEncode({
          'user_id': widget.userId,
          'question': messageText,
          'current_date': currentDate, 
        }),
      );

      final responseData = jsonDecode(response.body);
      String botResponse;

      if (response.statusCode == 200 && responseData['status'] == 'success') {
        botResponse = responseData['answer'];
        _speak(botResponse);
      } else {
        botResponse = responseData['message'] ?? "Sorry, I encountered an error.";
      }
      
      setState(() {
        _messages.add(ChatMessage(text: botResponse, isUser: false));
      });

    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(text: "Connection Failed. Please check your network, firewall, and that the server is running.", isUser: false));
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("FinManager AI"),
        foregroundColor: Colors.white,
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.blueGrey[800],
      ),
      backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.grey.shade100,
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              reverse: true,
              padding: const EdgeInsets.all(16.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[_messages.length - 1 - index];
                return _buildChatBubble(message);
              },
            ),
          ),
          if (_isLoading) _buildTypingIndicator(),
          if (!_isLoading && _messages.length <= 1) _buildExamplePrompts(),
          _buildTextInputArea(),
        ],
      ),
    );
  }

  Widget _buildChatBubble(ChatMessage message) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color userBubbleColor = Theme.of(context).primaryColor;
    final Color aiBubbleColor = isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200;

    return Row(
      mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!message.isUser)
          const CircleAvatar(
            child: Icon(Icons.support_agent),
            radius: 16,
          ),
        Flexible(
          child: Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: message.isUser ? userBubbleColor : aiBubbleColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              message.text,
              style: TextStyle(
                color: message.isUser ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
                fontSize: 16,
              ),
            ),
          ),
        ),
        if (!message.isUser)
          IconButton(
            icon: const Icon(Icons.volume_up_outlined),
            onPressed: () => _speak(message.text),
            color: Colors.grey,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
      ],
    );
  }
  
  Widget _buildTypingIndicator() {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        children: [
          CircleAvatar(
            child: const Icon(Icons.support_agent),
            radius: 16,
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const SizedBox(
              width: 40,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildExamplePrompts() {
    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: _examplePrompts.map((prompt) {
          return GestureDetector(
            onTap: () => _sendMessage(text: prompt),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: Center(child: Text(prompt, style: const TextStyle(fontWeight: FontWeight.w500))),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTextInputArea() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: [BoxShadow(offset: const Offset(0, -1), blurRadius: 2, color: Colors.black.withOpacity(0.1))]
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: _isListening ? "Listening..." : "Ask a question...",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[200],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onSubmitted: _isLoading ? null : (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
              onPressed: _speechEnabled ? (_isListening ? _stopListening : _startListening) : null,
              style: IconButton.styleFrom(
                backgroundColor: _isListening ? Colors.red : Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}