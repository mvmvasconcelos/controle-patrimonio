enum BatchFeedbackKind { success, duplicate, notFound, error }

class BatchFeedbackPlayer {
  Future<void> prepare() async {}

  Future<void> play(BatchFeedbackKind kind) async {}

  Future<void> dispose() async {}
}
