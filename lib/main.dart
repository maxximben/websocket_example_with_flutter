import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'package:uuid/uuid.dart';
import 'package:uuid/uuid_value.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TechMessenger Чаты',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const ChatListScreen(
        userId: '11111111-1111-1111-1111-111111111111',
      ),
    );
  }
}

class ChatListScreen extends StatefulWidget {
  final String userId;

  const ChatListScreen({super.key, required this.userId});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  late StompClient _client;
  List<ChatObject> _chats = [];
  bool _isConnected = false;
  bool _isLoading = true;
  String jwtToken = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJhbGljZV93IiwianRpIjoiMTExMTExMTEtMTExMS0xMTExLTExMTEtMTExMTExMTExMTExIiwidXNlcklkIjoiMTExMTExMTEtMTExMS0xMTExLTExMTEtMTExMTExMTExMTExIiwiaWF0IjoxNzYzMjI5NjY4LCJleHAiOjE3NjM4MzQ0Njh9.ejDyKRJLsAgWkSifCzxvKVNLGvaOUUumUPKggIn0WiA";

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
  }

  void _connectWebSocket() {
    _client = StompClient(
      config: StompConfig.sockJS(
        url: 'https://maxximben-tech-messenger-backend-e542.twc1.net/ws',
        onConnect: (frame) {
          setState(() {
            _isConnected = true;
            _isLoading = false;
          });

          _client.subscribe(
            destination: '/topic/get-chats/${widget.userId}',
            callback: (frame) => _handleChatUpdate(frame),
          );

          _sendChatRequest();
        },
        onWebSocketError: (error) {
          setState(() {
            _isConnected = false;
            _isLoading = false;
          });
          _showError('Ошибка подключения: $error');
        },
        onStompError: (error) => _showError('STOMP ошибка: $error'),
        onDisconnect: (_) => setState(() => _isConnected = false),
      ),
    );

    _client.activate();
  }

  void _handleChatUpdate(StompFrame frame) {
    if (frame.body == null) return;

    try {
      final List<dynamic> jsonList = jsonDecode(frame.body!);
      final List<ChatObject> updatedChats = jsonList
          .map((json) => ChatObject.fromJson(json))
          .toList();

      setState(() {
        _chats = _mergeChats(_chats, updatedChats);
      });
    } catch (e) {
      debugPrint('Ошибка парсинга обновления чатов: $e');
    }
  }

  List<ChatObject> _mergeChats(List<ChatObject> current, List<ChatObject> updates) {
    final Map<String, ChatObject> chatMap = {
      for (var chat in current) chat.chatId.toString(): chat
    };

    for (var update in updates) {
      chatMap[update.chatId.toString()] = update;
    }

    return chatMap.values.toList()
      ..sort((a, b) {
        if (a.lastMessageTime == null) return 1;
        if (b.lastMessageTime == null) return -1;
        return b.lastMessageTime!.compareTo(a.lastMessageTime!);
      });
  }

  void _sendChatRequest() {
    if (_isConnected) {
      _client.send(
        destination: '/app/user-chats/',
        headers: {'jwtToken': jwtToken},
        body: jsonEncode({}),
      );
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  void dispose() {
    _client.deactivate();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои чаты'),
        actions: [
          IconButton(
            icon: Icon(
              _isConnected ? Icons.circle : Icons.circle_outlined,
              color: _isConnected ? Colors.green : Colors.red,
            ),
            tooltip: _isConnected ? 'Подключено' : 'Отключено',
            onPressed: null,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _chats.isEmpty
          ? const Center(child: Text('Нет чатов'))
          : ListView.builder(
        itemCount: _chats.length,
        itemBuilder: (context, index) {
          final chat = _chats[index];
          return ListTile(
            leading: CircleAvatar(
              child: Text(
                chat.name.isNotEmpty ? chat.name[0].toUpperCase() : '?',
              ),
            ),
            title: Text(chat.name),
            subtitle: Text(
              chat.lastMessage ?? 'Нет сообщений',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: chat.lastMessageTime != null
                ? Text(
              _formatTime(chat.lastMessageTime!),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            )
                : null,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    chat: chat,
                    stompClient: _client,
                    jwtToken: jwtToken,
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isConnected ? _sendChatRequest : null,
        tooltip: 'Обновить',
        child: const Icon(Icons.refresh),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(time.year, time.month, time.day);

    if (date == today) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (date == today.subtract(const Duration(days: 1))) {
      return 'Вчера';
    } else {
      return '${time.day.toString().padLeft(2, '0')}.${time.month.toString().padLeft(2, '0')}';
    }
  }
}

// === DTO для сообщения ===
class MessageObject {
  final String senderName;
  final String messageText;
  final DateTime sentTime;

  MessageObject({
    required this.senderName,
    required this.messageText,
    required this.sentTime,
  });

  factory MessageObject.fromJson(Map<String, dynamic> json) {
    return MessageObject(
      senderName: json['senderName']?.toString() ?? 'Неизвестно',
      messageText: json['messageText']?.toString() ?? '',
      sentTime: json['sentTime'] != null
          ? DateTime.parse(json['sentTime'].toString())
          : DateTime.now(),
    );
  }
}

// === DTO для чата ===
class ChatObject {
  final UuidValue chatId;
  final String name;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final List<MessageObject>? messages;

  ChatObject({
    required this.chatId,
    required this.name,
    this.lastMessage,
    this.lastMessageTime,
    this.messages,
  });

  factory ChatObject.fromJson(Map<String, dynamic> json) {
    final uuidStr = json['chatId']?.toString();
    UuidValue parsedId;

    if (uuidStr != null && uuidStr.isNotEmpty) {
      try {
        parsedId = UuidValue(uuidStr);
      } catch (e) {
        debugPrint('Невалидный UUID: $uuidStr, используем v4');
        parsedId = UuidValue(const Uuid().v4());
      }
    } else {
      parsedId = UuidValue(const Uuid().v4());
    }

    return ChatObject(
      chatId: parsedId,
      name: json['name']?.toString() ?? 'Без имени',
      lastMessage: json['lastMessage']?.toString(),
      lastMessageTime: json['lastMessageTime'] != null
          ? DateTime.parse(json['lastMessageTime'].toString())
          : null,
      messages: json['messages'] != null
          ? (json['messages'] as List)
          .map((m) => MessageObject.fromJson(m as Map<String, dynamic>))
          .toList()
          : null,
    );
  }

  @override
  String toString() {
    return 'ChatObject{chatId: $chatId, name: $name, lastMessage: $lastMessage, messagesCount: ${messages?.length}}';
  }
}

// === Экран чата ===
class ChatScreen extends StatefulWidget {
  final ChatObject chat;
  final StompClient stompClient;
  final String jwtToken;

  const ChatScreen({
    super.key,
    required this.chat,
    required this.stompClient,
    required this.jwtToken,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  List<MessageObject> _messages = [];
  bool _isSubscribed = false;

  @override
  void initState() {
    super.initState();
    _messages = widget.chat.messages ?? [];
    _subscribeToChat();
  }

  void _subscribeToChat() {
    if (!_isSubscribed && widget.stompClient.connected) {
      widget.stompClient.subscribe(
        destination: '/topic/chat/${widget.chat.chatId}',
        callback: (frame) {
          if (frame.body != null) {
            try {
              final json = jsonDecode(frame.body!);
              final newMessage = MessageObject.fromJson(json);
              setState(() {
                _messages.add(newMessage);
              });
            } catch (e) {
              debugPrint('Ошибка парсинга сообщения: $e');
            }
          }
        },
      );
      _isSubscribed = true;
      _requestChatMessages();
    }
  }

  void _requestChatMessages() {
    widget.stompClient.send(
      destination: '/app/chat-messages/${widget.chat.chatId}',
      headers: {'jwtToken': widget.jwtToken},
      body: jsonEncode({}),
    );
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isNotEmpty) {
      final message = {
        'senderName': 'Me', // Замените на реальное имя пользователя
        'messageText': text,
        'sentTime': DateTime.now().toIso8601String(),
      };
      widget.stompClient.send(
        destination: '/app/send-message/${widget.chat.chatId}',
        headers: {'jwtToken': widget.jwtToken},
        body: jsonEncode(message),
      );
      _messageController.clear();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.chat.name),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return ListTile(
                  title: Text('${msg.senderName}: ${msg.messageText}'),
                  subtitle: Text(_formatTime(msg.sentTime)),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Введите сообщение...',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(time.year, time.month, time.day);

    if (date == today) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (date == today.subtract(const Duration(days: 1))) {
      return 'Вчера';
    } else {
      return '${time.day.toString().padLeft(2, '0')}.${time.month.toString().padLeft(2, '0')}';
    }
  }
}