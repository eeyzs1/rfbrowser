/// AI 采样参数配置。
///
/// 分聊天/Agent/Dreaming 三场景,每场景独立配置 temperature 和 max_tokens。
/// 修复此前主聊天不传采样参数、Anthropic 硬编码 max_tokens=4096、
/// Dreaming 硬编码 temperature=0.3/max_tokens=1024 的不一致问题。
///
/// 另含 Agent 执行参数 [maxToolLoops] / [maxReactIterations],
/// 替代原先散落在 ai_service_tool_loop.dart 和 agent_task.dart 的硬编码常量。
///
/// 持久化到 SharedPreferences,key 前缀 `sampling*`。
library;

import 'package:shared_preferences/shared_preferences.dart';

class SamplingSettings {
  /// 聊天场景 temperature(默认 0.7,平衡多样性与连贯性)。
  final double chatTemperature;

  /// 聊天场景 max_tokens(null 表示不传,由 provider 决定默认值)。
  final int? chatMaxTokens;

  /// Agent 任务 temperature(默认 0.3,偏确定性以提升工具调用可靠性)。
  final double agentTemperature;

  /// Agent 任务 max_tokens(默认 4096,留足工具调用空间)。
  final int agentMaxTokens;

  /// Dreaming 整理 temperature(默认 0.3,摘要要忠实于原文)。
  final double dreamingTemperature;

  /// Dreaming 整理 max_tokens(默认 1024,摘要无需过长)。
  final int dreamingMaxTokens;

  /// 聊天模式 tool-call 循环最大轮数(默认 10)。
  ///
  /// 控制 [handleToolCallLoop] 中"AI 返回 tool_call → 执行 → 再请求 AI"
  /// 的最大循环次数,防止模型陷入"调用工具 → 收到结果 → 又调用工具"死循环。
  /// 到达上限后强制结束循环,把最后一条 assistant 文本返回给用户。
  final int maxToolLoops;

  /// Agent ReAct 循环最大迭代数(默认 50,与 AgentTask.maxIterations 默认值一致)。
  ///
  /// 用于 [ReactLoopExecutionStrategy],控制 observe→think→act 的最大轮数。
  /// 实际生效值会被 clamp 到 [TaskExecutionStrategy.maxSteps] 以内。
  final int maxReactIterations;

  const SamplingSettings({
    this.chatTemperature = 0.7,
    this.chatMaxTokens,
    this.agentTemperature = 0.3,
    this.agentMaxTokens = 4096,
    this.dreamingTemperature = 0.3,
    this.dreamingMaxTokens = 1024,
    this.maxToolLoops = 10,
    this.maxReactIterations = 50,
  });

  /// 从 [SharedPreferences] 读取配置。未设置的字段使用默认值。
  factory SamplingSettings.fromPrefs(SharedPreferences prefs) {
    return SamplingSettings(
      chatTemperature: prefs.getDouble('samplingChatTemperature') ?? 0.7,
      chatMaxTokens: prefs.getInt('samplingChatMaxTokens'),
      agentTemperature: prefs.getDouble('samplingAgentTemperature') ?? 0.3,
      agentMaxTokens: prefs.getInt('samplingAgentMaxTokens') ?? 4096,
      dreamingTemperature:
          prefs.getDouble('samplingDreamingTemperature') ?? 0.3,
      dreamingMaxTokens: prefs.getInt('samplingDreamingMaxTokens') ?? 1024,
      maxToolLoops: prefs.getInt('samplingMaxToolLoops') ?? 10,
      maxReactIterations: prefs.getInt('samplingMaxReactIterations') ?? 50,
    );
  }

  SamplingSettings copyWith({
    double? chatTemperature,
    int? chatMaxTokens,
    bool clearChatMaxTokens = false,
    double? agentTemperature,
    int? agentMaxTokens,
    double? dreamingTemperature,
    int? dreamingMaxTokens,
    int? maxToolLoops,
    int? maxReactIterations,
  }) {
    return SamplingSettings(
      chatTemperature: chatTemperature ?? this.chatTemperature,
      chatMaxTokens: clearChatMaxTokens
          ? null
          : (chatMaxTokens ?? this.chatMaxTokens),
      agentTemperature: agentTemperature ?? this.agentTemperature,
      agentMaxTokens: agentMaxTokens ?? this.agentMaxTokens,
      dreamingTemperature: dreamingTemperature ?? this.dreamingTemperature,
      dreamingMaxTokens: dreamingMaxTokens ?? this.dreamingMaxTokens,
      maxToolLoops: maxToolLoops ?? this.maxToolLoops,
      maxReactIterations: maxReactIterations ?? this.maxReactIterations,
    );
  }

  @override
  String toString() =>
      'SamplingSettings(chatT=$chatTemperature, chatMax=$chatMaxTokens, '
      'agentT=$agentTemperature, agentMax=$agentMaxTokens, '
      'dreamT=$dreamingTemperature, dreamMax=$dreamingMaxTokens, '
      'maxToolLoops=$maxToolLoops, maxReactIter=$maxReactIterations)';
}
