import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
        userId: '11111111-1111-1111-1111-111111111111', // Замените на ваш UUID
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
        url: 'https://maxximben-tech-messenger-backend-e542.twc1.net/ws', // Замените на ваш сервер
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

  // Объединяем обновлённые чаты с текущим списком (обновляем только изменённые)
  List<ChatObject> _mergeChats(List<ChatObject> current, List<ChatObject> updates) {
    final Map<String, ChatObject> chatMap = {
      for (var chat in current) chat.chatId: chat
    };

    for (var update in updates) {
      chatMap[update.chatId] = update;
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Открыть чат: ${chat.chatId}')),
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

// === DTO для чата ===
class ChatObject {
  final String chatId;
  final String name;
  final String? lastMessage;
  final DateTime? lastMessageTime;

  ChatObject({
    required this.chatId,
    required this.name,
    this.lastMessage,
    this.lastMessageTime,
  });

  factory ChatObject.fromJson(Map<String, dynamic> json) {
    return ChatObject(
      chatId: json['chatId']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Без имени',
      lastMessage: json['lastMessage']?.toString(),
      lastMessageTime: json['lastMessageTime'] != null
          ? DateTime.tryParse(json['lastMessageTime'].toString())
          : null,
    );
  }
}

