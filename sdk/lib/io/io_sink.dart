// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of dart.io;

/// A combined byte and text output.
///
/// An [IOSink] combines a [StreamSink] of bytes with a [StringSink],
/// and allows easy output of both bytes and text.
///
/// Writing text ([write]) and adding bytes ([add]) may be interleaved freely.
///
/// While a stream is being added using [addStream], any further attempts
/// to add or write to the [IOSink] will fail until the [addStream] completes.
///
/// It is an error to add data to the [IOSink] after the sink is closed.
abstract class IOSink implements StreamSink<List<int>>, StringSink {
  /// Create an [IOSink] that outputs to a [target] [StreamConsumer] of bytes.
  ///
  /// Text written to [StreamSink] methods is encoded to bytes using [encoding]
  /// before being output on [target].
  factory IOSink(StreamConsumer<List<int>> target,
          {Encoding encoding = utf8}) =>
      new _IOSinkImpl(target, encoding);

  /// The [Encoding] used when writing strings.
  ///
  /// Depending on the underlying consumer, this property might be mutable.
  late Encoding encoding;

  /// Adds byte [data] to the target consumer, ignoring [encoding].
  ///
  /// The [encoding] does not apply to this method, and the [data] list is passed
  /// directly to the target consumer as a stream event.
  ///
  /// This function must not be called when a stream is currently being added
  /// using [addStream].
  ///
  /// This operation is non-blocking. See [flush] or [done] for how to get any
  /// errors generated by this call.
  ///
  /// The data list should not be modified after it has been passed to `add`
  /// because it is not defined whether the target consumer will receive the
  /// list in the original or modified state.
  void add(List<int> data);

  /// Converts [object] to a String by invoking [Object.toString] and
  /// [add]s the encoding of the result to the target consumer.
  ///
  /// This operation is non-blocking. See [flush] or [done] for how to get any
  /// errors generated by this call.
  void write(Object? object);

  /// Iterates over the given [objects] and [write]s them in sequence.
  ///
  /// If [separator] is provided, a `write` with the `separator` is performed
  /// between any two elements of objects.
  ///
  /// This operation is non-blocking. See [flush] or [done] for how to get any
  /// errors generated by this call.
  void writeAll(Iterable objects, [String separator = ""]);

  /// Converts [object] to a String by invoking [Object.toString] and
  /// writes the result to `this`, followed by a newline.
  ///
  /// This operation is non-blocking. See [flush] or [done] for how to get any
  /// errors generated by this call.
  void writeln([Object? object = ""]);

  /// Writes the character of [charCode].
  ///
  /// This method is equivalent to `write(String.fromCharCode(charCode))`.
  ///
  /// This operation is non-blocking. See [flush] or [done] for how to get any
  /// errors generated by this call.
  void writeCharCode(int charCode);

  /// Passes the error to the target consumer as an error event.
  ///
  /// This function must not be called when a stream is currently being added
  /// using [addStream].
  ///
  /// This operation is non-blocking. See [flush] or [done] for how to get any
  /// errors generated by this call.
  void addError(error, [StackTrace? stackTrace]);

  /// Adds all elements of the given [stream].
  ///
  /// Returns a [Future] that completes when
  /// all elements of the given [stream] have been added.
  ///
  /// If the stream contains an error, the `addStream` ends at the error,
  /// and the returned future completes with that error.
  ///
  /// This function must not be called when a stream is currently being added
  /// using this function.
  Future addStream(Stream<List<int>> stream);

  /// Returns a [Future] that completes once all buffered data is accepted by the
  /// underlying [StreamConsumer].
  ///
  /// This method must not be called while an [addStream] is incomplete.
  ///
  /// NOTE: This is not necessarily the same as the data being flushed by the
  /// operating system.
  Future flush();

  /// Close the target consumer.
  ///
  /// NOTE: Writes to the [IOSink] may be buffered, and may not be flushed by
  /// a call to `close()`. To flush all buffered writes, call `flush()` before
  /// calling `close()`.
  Future close();

  /// A future that will complete when the consumer closes, or when an
  /// error occurs.
  ///
  /// This future is identical to the future returned by [close].
  Future get done;
}

class _StreamSinkImpl<T> implements StreamSink<T> {
  final StreamConsumer<T> _target;
  final Completer _doneCompleter = new Completer();
  StreamController<T>? _controllerInstance;
  Completer? _controllerCompleter;
  bool _isClosed = false;
  bool _isBound = false;
  bool _hasError = false;

  _StreamSinkImpl(this._target);

  void add(T data) {
    if (_isClosed) {
      throw StateError("StreamSink is closed");
    }
    _controller.add(data);
  }

  void addError(error, [StackTrace? stackTrace]) {
    if (_isClosed) {
      throw StateError("StreamSink is closed");
    }
    _controller.addError(error, stackTrace);
  }

  Future addStream(Stream<T> stream) {
    if (_isBound) {
      throw new StateError("StreamSink is already bound to a stream");
    }
    if (_hasError) return done;

    _isBound = true;
    var future = _controllerCompleter == null
        ? _target.addStream(stream)
        : _controllerCompleter!.future.then((_) => _target.addStream(stream));
    _controllerInstance?.close();

    // Wait for any pending events in [_controller] to be dispatched before
    // adding [stream].
    return future.whenComplete(() {
      _isBound = false;
    });
  }

  Future flush() {
    if (_isBound) {
      throw new StateError("StreamSink is bound to a stream");
    }
    if (_controllerInstance == null) return new Future.value(this);
    // Adding an empty stream-controller will return a future that will complete
    // when all data is done.
    _isBound = true;
    var future = _controllerCompleter!.future;
    _controllerInstance!.close();
    return future.whenComplete(() {
      _isBound = false;
    });
  }

  Future close() {
    if (_isBound) {
      throw new StateError("StreamSink is bound to a stream");
    }
    if (!_isClosed) {
      _isClosed = true;
      if (_controllerInstance != null) {
        _controllerInstance!.close();
      } else {
        _closeTarget();
      }
    }
    return done;
  }

  void _closeTarget() {
    _target.close().then(_completeDoneValue, onError: _completeDoneError);
  }

  Future get done => _doneCompleter.future;

  void _completeDoneValue(value) {
    if (!_doneCompleter.isCompleted) {
      _doneCompleter.complete(value);
    }
  }

  void _completeDoneError(error, StackTrace? stackTrace) {
    if (!_doneCompleter.isCompleted) {
      _hasError = true;
      _doneCompleter.completeError(error, stackTrace);
    }
  }

  StreamController<T> get _controller {
    if (_isBound) {
      throw new StateError("StreamSink is bound to a stream");
    }
    if (_isClosed) {
      throw new StateError("StreamSink is closed");
    }
    if (_controllerInstance == null) {
      _controllerInstance = new StreamController<T>(sync: true);
      _controllerCompleter = new Completer();
      _target.addStream(_controller.stream).then((_) {
        if (_isBound) {
          // A new stream takes over - forward values to that stream.
          _controllerCompleter!.complete(this);
          _controllerCompleter = null;
          _controllerInstance = null;
        } else {
          // No new stream, .close was called. Close _target.
          _closeTarget();
        }
      }, onError: (error, stackTrace) {
        if (_isBound) {
          // A new stream takes over - forward errors to that stream.
          _controllerCompleter!.completeError(error, stackTrace);
          _controllerCompleter = null;
          _controllerInstance = null;
        } else {
          // No new stream. No need to close target, as it has already
          // failed.
          _completeDoneError(error, stackTrace);
        }
      });
    }
    return _controllerInstance!;
  }
}

class _IOSinkImpl extends _StreamSinkImpl<List<int>> implements IOSink {
  Encoding _encoding;
  bool _encodingMutable = true;

  _IOSinkImpl(StreamConsumer<List<int>> target, this._encoding) : super(target);

  Encoding get encoding => _encoding;

  void set encoding(Encoding value) {
    if (!_encodingMutable) {
      throw new StateError("IOSink encoding is not mutable");
    }
    _encoding = value;
  }

  void write(Object? obj) {
    String string = '$obj';
    if (string.isEmpty) return;
    add(_encoding.encode(string));
  }

  void writeAll(Iterable objects, [String separator = ""]) {
    Iterator iterator = objects.iterator;
    if (!iterator.moveNext()) return;
    if (separator.isEmpty) {
      do {
        write(iterator.current);
      } while (iterator.moveNext());
    } else {
      write(iterator.current);
      while (iterator.moveNext()) {
        write(separator);
        write(iterator.current);
      }
    }
  }

  void writeln([Object? object = ""]) {
    write(object);
    write("\n");
  }

  void writeCharCode(int charCode) {
    write(new String.fromCharCode(charCode));
  }
}
