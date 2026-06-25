part of 'ai_service.dart';

/// Mixin that handles the streaming tool-call loop for [AINotifier].
///
/// Declares the private dependencies it needs from the host class so
/// the compiler can verify they exist at mix-in time. Because this is
/// a part file, the private names share the same library scope.
mixin _ToolCallLoopMixin on Notifier<AIState> {
  AiProtocolStrategy get protocolStrategy;
  void updateLastAssistantMessage(
    String content, {
    required bool isStreaming,
    bool attachMemoryFootprint = false,
  });
  void removeLastAssistantMessage();
  void persistMessage(String role, String content);

  /// Process a streaming response that may contain tool calls.
  /// When tool calls are detected, execute them and loop until
  /// the AI returns a text-only response.
  Future<void> handleToolCallLoop(
    Response<dynamic> firstResponse,
    AIProvider provider,
    AIModel model,
    String? apiKey,
    AgentChatBridge bridge,
    List<Map<String, dynamic>> tools,
    List<Map<String, dynamic>> apiMessages,
  ) async {
    const maxLoops = 10;
    var currentMessages = List<Map<String, dynamic>>.from(apiMessages);
    var loopCount = 0;

    while (loopCount < maxLoops) {
      final accumulator = AiStreamAccumulator();

      // Read the stream
      final stream = (loopCount == 0)
          ? firstResponse.data.stream
          : (await protocolStrategy.sendRequest(
              provider: provider,
              model: model,
              messages: currentMessages,
              apiKey: apiKey,
              stream: true,
              tools: tools,
            )).data.stream;

      await for (final chunk in stream) {
        final text = utf8.decode(chunk);
        final lines = text.split('\n');
        for (final line in lines) {
          if (!line.startsWith('data: ')) continue;
          final data = line.substring(6).trim();
          if (data == '[DONE]') break;
          try {
            final json = jsonDecode(data);
            accumulator.accumulateChunk(json, provider.protocol);
            // Update UI with accumulated text in real time
            if (accumulator.text.isNotEmpty) {
              updateLastAssistantMessage(
                accumulator.text,
                isStreaming: true,
              );
            }
          } catch (e) {
            appLog.warning('Tool loop chunk parse error', error: e);
          }
        }
      }

      // Update UI with accumulated text
      final accumulatedText = accumulator.text;
      if (accumulatedText.isNotEmpty) {
        updateLastAssistantMessage(accumulatedText, isStreaming: true);
      }

      // Check if we have tool calls to execute
      if (!accumulator.hasToolCalls) {
        updateLastAssistantMessage(
          accumulatedText,
          isStreaming: false,
          attachMemoryFootprint: true,
        );
        // ── Memory: persist final assistant response ────────────
        if (accumulatedText.isNotEmpty) {
          persistMessage('assistant', accumulatedText);
        }
        // ─────────────────────────────────────────────────────────
        return;
      }

      // Execute tool calls
      final toolCalls = accumulator.toolCalls;

      // Build assistant message with tool_calls for the API
      final assistantToolCalls = toolCalls.map((tc) {
        return {
          'id': tc.id,
          'type': 'function',
          'function': {'name': tc.name, 'arguments': tc.argsJson},
        };
      }).toList();

      currentMessages.add({
        'role': 'assistant',
        'content': accumulatedText.isNotEmpty ? accumulatedText : null,
        'tool_calls': assistantToolCalls,
      });

      // Display tool calls in UI
      for (final tc in toolCalls) {
        final args = AiStreamAccumulator.parseArgs(tc.argsJson);
        final display = bridge.formatToolCallForDisplay(tc.name, args);

        // Add a display-only message for the tool call
        final callMsg = ChatMessage(
          role: 'tool_call',
          content: '',
          toolCallDisplay: display,
        );
        state = state.copyWith(messages: [...state.messages, callMsg]);

        // Execute the tool
        final result = await bridge.executeTool(tc.name, args);
        final resultDisplay = bridge.formatToolResultForDisplay(
          tc.name,
          result,
        );

        // Add tool result to API messages
        currentMessages.add({
          'role': 'tool',
          'tool_call_id': tc.id,
          'content': jsonEncode(result),
        });

        // Display tool result in UI
        final resultMsg = ChatMessage(
          role: 'tool_result',
          content: '',
          toolResultDisplay: resultDisplay,
        );
        state = state.copyWith(messages: [...state.messages, resultMsg]);
      }

      removeLastAssistantMessage();
      state = state.copyWith(isLoading: true);
      loopCount++;
    }

    // Max loops exceeded
    updateLastAssistantMessage(
      'Agent tool loop limit reached. Please simplify your request.',
      isStreaming: false,
      attachMemoryFootprint: true,
    );
  }
}
