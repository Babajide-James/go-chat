enum MessageType {
  text,
  audio,
  image,
  video;

  String get stringValue => name;
  static MessageType fromString(String value) {
    return MessageType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MessageType.text,
    );
  }
}
