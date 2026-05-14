enum MessageStatus {
  sending,
  sent,
  delivered,
  seen;

  String get stringValue => name;
  static MessageStatus fromString(String value) {
    return MessageStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MessageStatus.sent,
    );
  }
}
