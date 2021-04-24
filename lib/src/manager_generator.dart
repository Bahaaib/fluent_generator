import 'dart:async';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/src/builder/build_step.dart';
import 'package:fluent_translator/fluent_dependency.dart';
import 'package:source_gen/source_gen.dart';
import 'package:fluent_translator/src/locale_resolver.dart';

class LanguageManagerGenerator extends GeneratorForAnnotation<Fluent> {
  StringBuffer _generatedClassBuffer = StringBuffer();

  @override
  FutureOr<String> generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep buildStep) {
    _generateLanguageManagerSourceCode(element, annotation);

    return _generatedClassBuffer.toString();
  }

  void _generateLanguageManagerSourceCode(
      Element element, ConstantReader annotation) {
    //Evaluate annotation inputs before start generation
    _evaluateAnnotationInputs(annotation);

    _buildClassImports();
    _addLineBreak();
    _addClassName("LanguageManager");
    _buildClassFields(annotation);
    _addLineBreak();
    _buildInitFunction();
    _addLineBreak();
    _buildFetchCachedLanguageFunction();
    _addLineBreak();
    _buildDefaultLanguageFunction();
    _addLineBreak();
    _buildServerLocaleFunction();
    _addLineBreak();
    _buildCurrentLocaleFunction();
    _addLineBreak();
    _buildDisposeFunction();
    _addBlockClosingBracket();
    _buildLanguageSourceEnum();
  }

  void _evaluateAnnotationInputs(ConstantReader annotation) {
    String defaultLocale = annotation.peek('fallbackLanguage').stringValue;
    List<DartObject> languagesList =
        annotation.peek("supportedLanguages").listValue;

    List<String> supportedLanguages = List<String>();

    for (DartObject input in languagesList) {
      supportedLanguages.add(input.toStringValue());
    }

    Locale.evaluate(locale: defaultLocale, inputLocales: supportedLanguages);
  }

  void _addClassImport(String import, {String as}) {
    String asStatement = as != null ? 'as $as' : '';
    _generatedClassBuffer.writeln('import \'$import' '\' $asStatement;');
  }

  void _buildClassFields(ConstantReader annotation) {
    String defaultLocale = annotation.peek('fallbackLanguage').stringValue;

    _generatedClassBuffer
        .writeln("static final Fly _fly = GetIt.instance<Fly>();");
    _generatedClassBuffer.writeln(
        "static final PublishSubject<String> languageSubject = PublishSubject();");
    _generatedClassBuffer.writeln(
        "static final SharedPreferencesProvider _sharedPreferencesProvider = SharedPreferencesProvider();");
    _generatedClassBuffer
        .writeln("static String currentCode = \"$defaultLocale\";");
    _generatedClassBuffer.writeln("static String _selectedLangCode;");
  }

  void _buildInitFunction() {
    _generatedClassBuffer
        .writeln("static Future<void> init({LanguageSource source}) async {");
    _generatedClassBuffer
        .writeln("if (source == LanguageSource.LOCAL_CACHE) {");
    _generatedClassBuffer.writeln("await _fetchCachedLanguage();");
    _generatedClassBuffer.writeln("return;");
    _addBlockClosingBracket();
    _generatedClassBuffer.writeln(" _getDeviceDefaultLanguage();");
    _addBlockClosingBracket();
  }

  void _buildFetchCachedLanguageFunction() {
    _generatedClassBuffer
        .writeln("static Future<void> _fetchCachedLanguage() async {");
    _generatedClassBuffer.writeln(
        "_selectedLangCode = await _sharedPreferencesProvider.getLanguage();");
    _addLineBreak();
    _generatedClassBuffer.writeln(
        "assert(_selectedLangCode != null, 'Shared Preferences has no cached value for language');");
    _addLineBreak();
    _addComment("//Header for non-logged requests");
    _generatedClassBuffer
        .writeln("_fly.addHeaders({\"Lang\": _selectedLangCode});");
    _generatedClassBuffer.writeln("_setCurrentLocal(_selectedLangCode);");
    _addBlockClosingBracket();
  }

  void _buildDefaultLanguageFunction() {
    _generatedClassBuffer.writeln("static void _getDeviceDefaultLanguage() {");
    _generatedClassBuffer
        .writeln("_selectedLangCode = ui.window.locale.languageCode;");
    _addLineBreak();
    _addComment("//Header for non-logged requests");
    _generatedClassBuffer
        .writeln("_fly.addHeaders({\"Lang\": _selectedLangCode});");
    _generatedClassBuffer.writeln("_setCurrentLocal(_selectedLangCode);");
    _addBlockClosingBracket();
  }

  void _buildServerLocaleFunction() {
    _generatedClassBuffer.writeln(
        "static Future<void> setServerLocale({String id, String language, String languageNodeName, bool locallyCache = false}) async {");
    _generatedClassBuffer.writeln("if (locallyCache) {");
    _generatedClassBuffer
        .writeln("await _sharedPreferencesProvider.setLanguage(language);");
    _addBlockClosingBracket();
    _generatedClassBuffer.writeln("_setCurrentLocal(language);");
    _addLineBreak();
    _addComment("//Header for non-logged requests");
    _generatedClassBuffer.writeln("_fly.addHeaders({\"Lang\": language});");
    _addLineBreak();
    _generatedClassBuffer.writeln("if (id == null) return;");
    _addLineBreak();
    _generatedClassBuffer.writeln("try {");
    _addComment("//Request For logged Users");
    _generatedClassBuffer.writeln("Node changeLanguageNode = Node(");
    _generatedClassBuffer.writeln("name: languageNodeName,");
    _generatedClassBuffer.writeln("args: {");
    _generatedClassBuffer.writeln("'id': id,");
    _generatedClassBuffer.writeln("'locale': language,");
    _generatedClassBuffer.writeln("},");
    _generatedClassBuffer.writeln("cols: ['locale'],");
    _generatedClassBuffer.writeln(");");
    _addLineBreak();
    _generatedClassBuffer.writeln("await _fly.mutation([changeLanguageNode]);");
    _generatedClassBuffer.writeln("} catch (error) {");
    _generatedClassBuffer.writeln("rethrow;");
    _addBlockClosingBracket();
    _addBlockClosingBracket();
  }

  void _buildCurrentLocaleFunction() {
    _generatedClassBuffer
        .writeln("static void _setCurrentLocal(String code) {");
    _generatedClassBuffer.writeln("currentCode = code;");
    _generatedClassBuffer.writeln("languageSubject.add(currentCode);");
    _addBlockClosingBracket();
  }

  void _buildDisposeFunction() {
    _generatedClassBuffer.writeln("static void disposeLanguageSubject() {");
    _generatedClassBuffer.writeln("languageSubject.close();");
    _addBlockClosingBracket();
  }

  void _buildLanguageSourceEnum() {
    _generatedClassBuffer
        .writeln("enum LanguageSource { DEVICE, LOCAL_CACHE }");
  }

  void _buildClassImports() {
    _addClassImport("dart:async");
    _addClassImport("package:fly_networking/GraphQB/graph_qb.dart");
    _addClassImport("package:fly_networking/fly.dart");
    _addClassImport("package:get_it/get_it.dart");
    _addClassImport("package:rxdart/rxdart.dart");
    _addClassImport("dart:ui", as: "ui");
    _addClassImport("../provider/shared_preferences_provider.dart");
  }

  void _addClassName(String name) {
    _generatedClassBuffer.writeln("class $name {");
  }

  void _addBlockClosingBracket() {
    _generatedClassBuffer.writeln("}");
  }

  void _addComment(String comment) {
    _generatedClassBuffer.writeln('\t' + comment);
  }

  void _addLineBreak() {
    _generatedClassBuffer.writeln('\n');
  }
}
