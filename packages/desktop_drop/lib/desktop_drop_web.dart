import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:mime/mime.dart';

import 'src/web_drop_item.dart';

/// A web implementation of the DesktopDrop plugin.
class DesktopDropWeb {
  final MethodChannel channel;

  DesktopDropWeb._private(this.channel);

  static void registerWith(Registrar registrar) {
    final MethodChannel channel = MethodChannel(
      'desktop_drop',
      const StandardMethodCodec(),
      registrar,
    );

    final pluginInstance = DesktopDropWeb._private(channel);
    channel.setMethodCallHandler(pluginInstance.handleMethodCall);
    pluginInstance._registerEvents();
  }

  String _getMimeType(String text) {
    final pattern = RegExp(r'^data:([^;]+);');
    return pattern.firstMatch(text)?.group(1) ?? 'text/plain';
  }

  void _registerEvents() {
    html.window.onDrop.listen((event) {
      event.preventDefault();

      final items = event.dataTransfer.items;
      final webItems = List.generate(items?.length ?? 0, (index) {
        final item = items![index];
        if (item.kind == 'file') {
          final file = item.getAsFile()!;
          return WebDropItem(
            uri: html.Url.createObjectUrl(file),
            name: file.name,
            size: file.size,
            type: file.type,
            relativePath: file.relativePath,
            lastModified: file.lastModified != null
                ? DateTime.fromMillisecondsSinceEpoch(file.lastModified!)
                : file.lastModifiedDate,
            children: [],
          );
        }
        if (item.kind == 'string' && item.type == 'text/uri-list') {
          final data = event.dataTransfer.getData(item.type!);
          final mime = _getMimeType(data);
          return WebDropItem(
            uri: data,
            name: 'file.${extensionFromMime(mime)}',
            type: mime,
            data: base64Decode(data.split(';base64,')[1]),
            size: 0,
            relativePath: '',
            lastModified: DateTime.now(),
            children: [],
          );
        }
        // other types such as text/html
        return null;
      }).whereType<WebDropItem>().toList();
      channel.invokeMethod(
        "performOperation_web",
        webItems.map((e) => e.toJson()).toList(),
      );
    });

    html.window.onDragEnter.listen((event) {
      event.preventDefault();
      channel.invokeMethod('entered', [
        event.client.x.toDouble(),
        event.client.y.toDouble(),
      ]);
    });

    html.window.onDragOver.listen((event) {
      event.preventDefault();
      channel.invokeMethod('updated', [
        event.client.x.toDouble(),
        event.client.y.toDouble(),
      ]);
    });

    html.window.onDragLeave.listen((event) {
      event.preventDefault();
      channel.invokeMethod('exited', [
        event.client.x.toDouble(),
        event.client.y.toDouble(),
      ]);
    });
  }

  Future<dynamic> handleMethodCall(MethodCall call) async {
    throw PlatformException(
      code: 'Unimplemented',
      details: 'desktop_drop for web doesn\'t implement \'${call.method}\'',
    );
  }
}
