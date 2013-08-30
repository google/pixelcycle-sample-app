library util;

import 'dart:async' show Stream, StreamController;

/// Text holds a mutable string and reports changes to subscribers.
class Text {
  String _value;
  final StreamController<String> _onChange = new StreamController<String>.broadcast();

  Stream get onChange => _onChange.stream;

  String get value => _value;

  void set value(String newValue) {
    if (_value == newValue) {
      return;
    }
    _value = newValue;
    if (_onChange.hasListener) {
      _onChange.add(newValue);
    }
  }
}