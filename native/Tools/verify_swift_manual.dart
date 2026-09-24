import 'dart:convert';
import 'dart:io';
import '../../lib/domain/logging/program_log.dart';
void main(List<String> args){
  final entries=jsonDecode(File(args.single).readAsStringSync()) as List;
  for(final payload in entries){
    final log=ProgramLog.fromJson(jsonDecode(payload as String) as Map<String,dynamic>);
    if(jsonEncode(log.toJson())!=payload)throw StateError('Swift output is not Dart canonical');
    if(!log.endedEarly||log.sets.single.load!=30123456)throw StateError('Swift actuals changed');
  }
  print('Swift SQLite output read and canonicalized by Dart: ${entries.length} synthetic workout passed.');
}
