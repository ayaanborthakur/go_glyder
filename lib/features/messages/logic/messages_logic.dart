// lib/features/messages/logic/messages_logic.dart
//
// MessagesController — the single ChangeNotifier that owns all UI-side state
// for the direct-messaging feature.
//
// Widgets talk to this controller; this controller delegates all Firestore I/O
// to MessagingService (messages_fs.dart). This separation means:
//   • MessagingService is pure data — easy to unit-test or swap out.
//   • MessagesController owns loading/error/sending state — no scattered
//     setState calls across multiple widgets.
//
// Usage:
//   final ctrl = MessagesController.instance;
//   ctrl.subscribeToConversations();          // call once in MessagesPage.initState
//   ctrl.openChat(otherUid: ..., otherName: ...); // call in ChatDetailPage.initState
//   ctrl.closeChat();                         // call in ChatDetailPage.dispose
//   ctrl.sendMessage(...);                    // send a message
//   ctrl.unsubscribeFromConversations();      // call on sign-out

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:go_glyder/models/chat_message.dart';
import 'package:go_glyder/models/conversation.dart';
import 'package:go_glyder/services/messages_fs.dart';

class MessagesController extends ChangeNotifier {
  MessagesController._internal();
  static final MessagesController instance = MessagesController._internal();

  final MessagingService _service = MessagingService.instance;

  // ── Conversations list ─────────────────────────────────────────────────────

  List<Conversation> _conversations = [];
  bool _conversationsLoading = true;
  String? _conversationsError;
  StreamSubscription<List<Conversation>>? _convSub;

  /// Sorted list of the current user's conversations (newest first).
  List<Conversation> get conversations => _conversations;

  /// True while the initial conversation list is being loaded.
  bool get conversationsLoading => _conversationsLoading;

  /// Non-null when loading the conversation list failed.
  String? get conversationsError => _conversationsError;

  /// Begin listening to the user's conversations. Call once from
  /// [MessagesPage.initState]. Safe to call multiple times — re-subscribing
  /// is a no-op if a subscription is already active.
  void subscribeToConversations() {
    if (_convSub != null) return;
    _conversationsLoading = true;
    _conversationsError = null;
    notifyListeners();

    _convSub = _service.streamMyConversations().listen(
      (convs) {
        _conversations = convs;
        _conversationsLoading = false;
        _conversationsError = null;
        notifyListeners();
      },
      onError: (Object e) {
        _conversationsError = e is MessagingException
            ? e.message
            : 'Could not load conversations.';
        _conversationsLoading = false;
        notifyListeners();
      },
    );
  }

  /// Cancel the conversation-list subscription (e.g. on sign-out).
  void unsubscribeFromConversations() {
    _convSub?.cancel();
    _convSub = null;
    _conversations = [];
    _conversationsLoading = true;
    _conversationsError = null;
    notifyListeners();
  }

  // ── Active chat ────────────────────────────────────────────────────────────

  String? _activeChatConvId;
  List<ChatMessage> _activeMessages = [];
  bool _messagesLoading = false;
  String? _messagesError;
  StreamSubscription<List<ChatMessage>>? _msgSub;

  /// The Firestore conversation ID of the currently open chat, if any.
  String? get activeChatConvId => _activeChatConvId;

  /// Messages for the currently open chat, ordered by timestamp ascending.
  List<ChatMessage> get activeMessages => _activeMessages;

  /// True while the initial message list for the active chat is loading.
  bool get messagesLoading => _messagesLoading;

  /// Non-null when loading or sending a message failed.
  String? get messagesError => _messagesError;

  // ── Sending state ──────────────────────────────────────────────────────────

  bool _isSending = false;

  /// True while a [sendMessage] call is in-flight. Use to disable the send
  /// button and show a loading indicator.
  bool get isSending => _isSending;

  // ── Chat lifecycle ─────────────────────────────────────────────────────────

  /// Opens a chat thread with [otherUid]. Creates the conversation shell in
  /// Firestore if it doesn't exist yet, marks the thread as read, then begins
  /// streaming messages.
  ///
  /// Call from [ChatDetailPage.initState].
  Future<void> openChat({
    required String otherUid,
    required String otherName,
  }) async {
    // Close any previous chat subscription first.
    await _closeChatSubscription();

    _messagesLoading = true;
    _messagesError = null;
    notifyListeners();

    try {
      final convId = await _service.ensureConversation(
        otherUid: otherUid,
        otherName: otherName,
      );
      _activeChatConvId = convId;

      // Mark as read immediately upon opening.
      await _service.markConversationRead(convId);

      _msgSub = _service.streamConversationMessages(convId).listen(
        (msgs) {
          _activeMessages = msgs;
          _messagesLoading = false;
          _messagesError = null;
          notifyListeners();
        },
        onError: (Object e) {
          _messagesError = e is MessagingException
              ? e.message
              : 'Could not load messages.';
          _messagesLoading = false;
          notifyListeners();
        },
      );
    } on MessagingException catch (e) {
      _messagesError = e.message;
      _messagesLoading = false;
      notifyListeners();
    } catch (_) {
      _messagesError = 'Something went wrong opening the chat.';
      _messagesLoading = false;
      notifyListeners();
    }
  }

  /// Closes the active chat and cancels its message subscription.
  /// Call from [ChatDetailPage.dispose].
  void closeChat() {
    _closeChatSubscription();
  }

  Future<void> _closeChatSubscription() async {
    await _msgSub?.cancel();
    _msgSub = null;
    _activeChatConvId = null;
    _activeMessages = [];
    _messagesLoading = false;
    _messagesError = null;
    // No notifyListeners here — closeChat is called from dispose, where the
    // widget tree is already being torn down.
  }

  // ── Sending ────────────────────────────────────────────────────────────────

  /// Sends [text] to [otherUid]. Updates [isSending] before and after the
  /// write so the UI can disable the send button and show a spinner.
  Future<void> sendMessage({
    required String otherUid,
    required String otherName,
    required String text,
  }) async {
    if (_isSending) return;
    _isSending = true;
    _messagesError = null;
    notifyListeners();

    try {
      await _service.sendMessage(
        otherUid: otherUid,
        otherName: otherName,
        text: text,
      );
    } on MessagingException catch (e) {
      _messagesError = e.message;
    } catch (_) {
      _messagesError = 'Failed to send message. Please try again.';
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  /// Soft-deletes a message. The bubble in the UI should detect `isDeleted`
  /// and render "This message was deleted" instead of the original text.
  Future<void> deleteMessage({
    required String convId,
    required String messageId,
  }) async {
    try {
      await _service.deleteMessage(convId: convId, messageId: messageId);
    } on MessagingException catch (e) {
      _messagesError = e.message;
      notifyListeners();
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Current user's UID — proxied from MessagingService for convenience.
  String? get currentUid => _service.currentUid;

  /// Deterministic conversation ID for the pair (currentUid, otherUid).
  String conversationIdFor(String otherUid) =>
      _service.conversationIdFor(otherUid);

  /// Clears any displayed error banners.
  void clearError() {
    _conversationsError = null;
    _messagesError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _convSub?.cancel();
    _msgSub?.cancel();
    super.dispose();
  }
}
