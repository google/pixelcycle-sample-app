library share;

import 'dart:async' show Future, Completer;
import 'dart:html' show HttpRequest, HttpRequestProgressEvent;

/// Saves the current state and returns a new URL that can be used to load it.
Future<String> save(String data) {
  return post("/_share", data);
}

/// Loads the player state with the given id.
Future<String> load(String id) {
  return HttpRequest.getString("/_load?id=${id}");
}

/// Posts a string to the server and returns the response body as a string.
Future<String> post(String url, String data) {
  Completer done = new Completer();

  var r = new HttpRequest();

  r.onReadyStateChange.listen((e) {
    if (r.readyState == 4) {
      if (r.status == 200) {
        done.complete(r.responseText);
      } else {
        done.completeError("request failed with ${r.status}");
      }
    }
  });

  r.open("POST", url, async: true);
  r.send(data);

  return done.future;
}