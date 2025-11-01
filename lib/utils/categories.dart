const Map<String, String> kServiceCategoryLabels = {
  'PLOMERIA': 'Plomería',
  'CARPINTERIA': 'Carpintería',
  'ASEO': 'Aseo',
  'ELECTRICIDAD': 'Electricidad',
  'PINTURA': 'Pintura',
  'JARDINERIA': 'Jardinería',
  'COSTURA': 'Costura',
  'COCINA': 'Cocina',
  'TECNOLOGIA': 'Tecnología',
};

String _stripDiacritics(String input) {
  const Map<String, String> replacements = {
    'Á': 'A', 'À': 'A', 'Â': 'A', 'Ã': 'A', 'Ä': 'A', 'á': 'A',
    'É': 'E', 'È': 'E', 'Ê': 'E', 'Ë': 'E', 'é': 'E', 'è': 'E',
    'Í': 'I', 'Ì': 'I', 'Î': 'I', 'Ï': 'I', 'í': 'I', 'ì': 'I',
    'Ó': 'O', 'Ò': 'O', 'Ô': 'O', 'Ö': 'O', 'Õ': 'O', 'ó': 'O',
    'Ú': 'U', 'Ù': 'U', 'Û': 'U', 'Ü': 'U', 'ú': 'U', 'ù': 'U',
    'Ñ': 'N', 'ñ': 'N',
  };

  final buffer = StringBuffer();
  for (final rune in input.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(replacements[char] ?? char);
  }
  return buffer.toString();
}

String normalizeCategoryValue(String? raw) {
  if (raw == null) return '';
  final sanitized = _stripDiacritics(raw).toUpperCase().trim();
  if (sanitized.isEmpty) return '';
  for (final key in kServiceCategoryLabels.keys) {
    if (_stripDiacritics(key).toUpperCase() == sanitized) {
      return key;
    }
  }
  return sanitized;
}

String categoryDisplayLabel(String? value) {
  if (value == null || value.isEmpty) return '';
  final normalized = normalizeCategoryValue(value);
  return kServiceCategoryLabels[normalized] ?? value;
}

