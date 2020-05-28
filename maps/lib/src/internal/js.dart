// Copyright 2020 Gohilla Ltd.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

const _htmlAttributeForAttributeViewId = 'flutter-map-id';

var _htmlViewCounter = 0;

Widget buildHtmlViewFromElement(html.Element element) {
  final existingViewId = element.getAttribute(_htmlAttributeForAttributeViewId);
  if (existingViewId != null) {
    return HtmlElementView(
      viewType: existingViewId,
    );
  }
  final id = 'flutter-map-$_htmlViewCounter';
  _htmlViewCounter++;
  element.setAttribute(_htmlAttributeForAttributeViewId, id);
  ui.platformViewRegistry.registerViewFactory(
    id,
    (int viewId) => element,
  );
  return HtmlElementView(
    viewType: id,
  );
}

class LoadedScript {
  final String src;
  final String readyFunctionName;
  final bool Function() isLoadedCallback;

  const LoadedScript({
    @required this.src,
    @required this.readyFunctionName,
    @required this.isLoadedCallback,
  })  : assert(src != null),
        assert(readyFunctionName != null),
        assert(isLoadedCallback != null);

  @override
  int get hashCode => src.hashCode;

  bool get isLoaded => isLoadedCallback();

  @override
  bool operator ==(other) =>
      other is LoadedScript &&
      src == other.src &&
      readyFunctionName == other.readyFunctionName;

  Future<void> load() async {
    if (isLoaded) {
      return;
    }
    for (var element in html.document.getElementsByTagName('script')) {
      if (element is html.ScriptElement) {
        if (element.src == src) {
          //
          // Check periodically
          //
          final completer = Completer<void>();
          final timer =
              Timer.periodic(const Duration(milliseconds: 50), (timer) {
            if (isLoaded) {
              timer.cancel();
              completer.complete();
            }
          });
          return completer.future
              .timeout(const Duration(seconds: 10))
              .whenComplete(() {
            timer.cancel();
          });
        }
      }
    }
    final completer = Completer<void>();
    js.context[readyFunctionName] = js.allowInterop(() {
      js.context.deleteProperty(readyFunctionName);
      completer.complete();
    });
    final element = html.ScriptElement()..src = src;
    html.document.head.append(element);
    return completer.future;
  }
}
