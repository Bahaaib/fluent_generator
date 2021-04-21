import 'package:build/build.dart';
import 'package:fluent_translator_generator/src/fluent_generator.dart';
import 'package:source_gen/source_gen.dart';
import 'package:fluent_translator_generator/src/manager_generator.dart';

Builder fluent(BuilderOptions options) =>
    LibraryBuilder(FluentGenerator(), generatedExtension: '.gen.dart');

Builder languageManager(BuilderOptions options) =>
    LibraryBuilder(LanguageManagerGenerator(), generatedExtension: '.manager.gen.dart');
