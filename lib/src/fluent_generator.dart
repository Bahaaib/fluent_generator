import 'dart:async';
import 'dart:io';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/src/builder/build_step.dart';
import 'package:fluent_translator/fluent_dependency.dart';
import 'package:source_gen/source_gen.dart';
import 'package:fluent_translator/src/locale_resolver.dart';
import 'dart:convert' show utf8;
import 'package:csv/csv.dart';

class FluentGenerator extends GeneratorForAnnotation<Fluent> {
  StringBuffer _generatedClassBuffer = StringBuffer();

  @override
  FutureOr<String> generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep buildStep) async {
    //In case user provided [Translatable] objects
    if (annotation?.peek('fromCSV')?.isNull ?? true) {
      _generateTranslatableSourceCode(element, annotation);
      return _generatedClassBuffer.toString();
    }

    //In case user provided a CSV file
    String filePath = annotation.peek('fromCSV').stringValue;

    await _generateFromCSVFile(element, annotation, filePath);
    return _generatedClassBuffer.toString();
  }

  Future<void> _generateFromCSVFile(
      Element element, ConstantReader annotation, String filePath) async {
    String filePath = annotation.peek('fromCSV').stringValue;

    final input = new File(filePath).openRead();
    final fields = await input
        .transform(utf8.decoder)
        .transform(CsvToListConverter())
        .toList();

    List<List<String>> columns = _convertRowsToColumns(fields);
    List<String> supportedLocales = _getSupportedLocales(columns);
    List<String> fieldNames = _getFieldNames(columns);

    _buildClassImports(element);
    _addLineBreak();
    _addClassName("AppStrings");
    _addLineBreak();
    _buildTranslationsMapFromFile(supportedLocales, fieldNames, columns);
    _addLineBreak();
    _buildClassFieldsForFile(fieldNames);
    _addLineBreak();
    _addBlockClosingBracket();
  }

  void _buildTranslationsMapFromFile(List<String> supportedLocales,
      List<String> fieldNames, List<List<String>> translationColumns) {
    _generatedClassBuffer.writeln(
        'static Map<String, Map<String, String>> _translationsMap = {');

    for (int i = 0; i < supportedLocales.length; i++) {
      _generatedClassBuffer.writeln('"${supportedLocales[i]}": {');

      for (int j = 1; j < translationColumns[i].length; j++) {
        String translation = translationColumns[i][j];

        _generatedClassBuffer
            .writeln('\'${fieldNames[j - 1]}\' : ' '\"$translation\",');
      }
      _addMapClosingBracket();
    }
    _generatedClassBuffer.writeln('};');
  }

  void _buildClassFieldsForFile(List<String> fieldNames) {
    for (String fieldName in fieldNames) {
      _generatedClassBuffer.writeln(
          'static String get $fieldName => _translationsMap[LanguageManager.currentCode]["$fieldName"];');
    }
  }

  List<String> _getSupportedLocales(List<List<String>> columns) {
    List<String> locales = List();

    columns.forEach((columnCell) {
      if (columnCell[0] != 'fieldName') {
        locales.add(columnCell[0]);
      }
    });
    return locales;
  }

  List<String> _getFieldNames(List<List<String>> columns) {
    List<String> fields = List();

    columns.last.forEach((columnCell) {
      if (columnCell != 'fieldName') {
        fields.add(columnCell);
      }
    });
    return fields;
  }

  List<List<String>> _convertRowsToColumns(List<List<dynamic>> rows) {
    List<List<String>> columns = List();

    for (int i = 0; i < rows[0].length; i++) {
      List<String> columnCell = List();

      for (List<dynamic> row in rows) {
        if (row[i].toString() == '') return columns;
        print(row[i]);
        columnCell.add(row[i].toString());
      }

      columns.add(columnCell);
    }
    return columns;
  }

  void _generateTranslatableSourceCode(
      Element element, ConstantReader annotation) {
    //Evaluate annotation inputs before start generation
    _evaluateAnnotationInputs(annotation);

    _buildClassImports(element);
    _addLineBreak();
    _addClassName("AppStrings");
    _addLineBreak();
    _buildTranslationMaps(annotation);
    _addLineBreak();
    _buildClassFields(annotation);
    _addLineBreak();
    _addBlockClosingBracket();
  }

  void _buildClassFields(ConstantReader annotation) {
    List<DartObject> translationAnnotations =
        annotation.peek('translations').listValue;

    for (DartObject annotationObject in translationAnnotations) {
      String name = annotationObject.getField('fieldName').toStringValue();

      _generatedClassBuffer.writeln(
          'static String get $name => _translationsMap[LanguageManager.currentCode]["$name"];');
    }
  }

  void _buildTranslationMaps(ConstantReader annotation) {
    String fallbackLocale = annotation.peek('fallbackLanguage').stringValue;
    List<DartObject> translationAnnotations =
        annotation.peek('translations').listValue;

    _generatedClassBuffer.writeln(
        'static Map<String, Map<String, String>> _translationsMap = {');

    for (String locale in _getSupportedLanguages(annotation)) {
      _generatedClassBuffer.writeln('"$locale": {');
      for (DartObject annotationObject in translationAnnotations) {
        String name = annotationObject.getField('fieldName').toStringValue();

        String translation;
        DartObject translationObject =
            annotationObject.getField(Locale.resolveLocale(locale));
        DartObject fallbackTranslationObject =
            annotationObject.getField(Locale.resolveLocale(fallbackLocale));

        if ((translationObject == null || translationObject.isNull)) {
          if (fallbackTranslationObject == null ||
              fallbackTranslationObject.isNull) {
            throw '\u001b[31m' +
                'Can\'t find fallback translation on Translatable ===> $name' +
                '\u001b[0m';
          }
          translation = annotationObject
              .getField(Locale.resolveLocale(fallbackLocale))
              .toStringValue();
        } else {
          translation = annotationObject
              .getField(Locale.resolveLocale(locale))
              .toStringValue();
        }
        _generatedClassBuffer.writeln('\'$name\' : ' '\"$translation\",');
      }
      _addMapClosingBracket();
    }
    _generatedClassBuffer.writeln('};');
  }

  List<String> _getSupportedLanguages(ConstantReader annotation) {
    List<DartObject> languagesList =
        annotation.peek("supportedLanguages").listValue;

    List<String> supportedLanguages = List<String>();

    for (DartObject input in languagesList) {
      supportedLanguages.add(input.toStringValue());
    }

    return supportedLanguages;
  }

  void _buildClassImports(Element element) {
    String fileName = element.source.shortName.replaceAll('.dart', '');
    _addClassImport("../language/$fileName.manager.gen.dart");
  }

  void _addClassImport(String import, {String as}) {
    String asStatement = as != null ? 'as $as' : '';
    _generatedClassBuffer.writeln('import \'$import' '\' $asStatement;');
  }

  void _addClassName(String name) {
    _generatedClassBuffer.writeln("class $name {");
  }

  void _addMapClosingBracket() {
    _generatedClassBuffer.writeln("},");
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
}
