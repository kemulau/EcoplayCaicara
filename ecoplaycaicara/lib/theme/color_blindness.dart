import 'package:flutter/material.dart';

/// Utilitários de simulação de deficiências de visão de cores (CVD)
///
/// Este módulo expõe:
/// - `ColorVisionType`: enum com os tipos suportados;
/// - Matrizes 4x5 para uso em `ColorFilter.matrix` (aplicação global);
/// - Funções de apoio para filtro, rótulos e persistência.
///
/// Sobre as matrizes
/// ------------------
/// As matrizes aqui definidas são aproximações difundidas na literatura e
/// na prática para simulação de protanopia, deuteranopia e tritanopia.
/// Elas seguem o padrão de uma matriz 4x5 usada pelo Flutter:
///
///   [
///     rR, rG, rB, rA, rBias,
///     gR, gG, gB, gA, gBias,
///     bR, bG, bB, bA, bBias,
///     aR, aG, aB, aA, aBias,
///   ]
///
/// em que cada linha define a composição do novo canal (R,G,B,A) como uma
/// combinação linear dos canais de entrada e um termo de bias.
///
/// Referências (de interesse acadêmico/TCC)
/// - Vienot, F., Brettel, H., & Mollon, J. D. (1999). Digital video colourmaps
///   for checking the legibility of displays by dichromats. Color Research and
///   Application, 24(4), 243–252.
/// - Machado, G. M., Oliveira, M. M., & Fernandes, L. A. F. (2009). A
///   Physiologically-based Model for Simulation of Color Vision Deficiency.
///   IEEE TVCG, 15(6), 1291–1298. (implementações populares derivam desses)
/// - Materiais de ferramentas como Color Oracle e filtros equivalentes usados
///   em pipelines de UI/Accessibility.
///
/// Observações importantes
/// - Simulações são aproximações; a percepção varia entre indivíduos.
/// - O filtro deve ser combinado com testes de contraste e semântica visual.

/// Tipos de daltonismo suportados
enum ColorVisionType {
  normal,
  protanopia,
  deuteranopia,
  tritanopia,
  achromatopsia,
}

/// Matriz identidade (sem alteração)
const List<double> _identityMatrix = <double>[
  1, 0, 0, 0, 0,
  0, 1, 0, 0, 0,
  0, 0, 1, 0, 0,
  0, 0, 0, 1, 0,
];

/// Matrizes de simulação de daltonismo (aproximações amplamente utilizadas)
/// Cada lista possui 20 valores (4x5) para ColorFilter.matrix.
const Map<ColorVisionType, List<double>> _cvdMatrices = {
  ColorVisionType.normal: _identityMatrix,

  // Protanopia: deficiência nos cones sensíveis ao vermelho
  ColorVisionType.protanopia: <double>[
    0.567, 0.433, 0.000, 0, 0,
    0.558, 0.442, 0.000, 0, 0,
    0.000, 0.242, 0.758, 0, 0,
    0.000, 0.000, 0.000, 1, 0,
  ],

  // Deuteranopia: deficiência nos cones sensíveis ao verde
  ColorVisionType.deuteranopia: <double>[
    0.625, 0.375, 0.000, 0, 0,
    0.700, 0.300, 0.000, 0, 0,
    0.000, 0.300, 0.700, 0, 0,
    0.000, 0.000, 0.000, 1, 0,
  ],

  // Tritanopia: deficiência nos cones sensíveis ao azul
  ColorVisionType.tritanopia: <double>[
    0.950, 0.050, 0.000, 0, 0,
    0.000, 0.433, 0.567, 0, 0,
    0.000, 0.475, 0.525, 0, 0,
    0.000, 0.000, 0.000, 1, 0,
  ],

  // Acromatopsia: ausência de percepção de cor (tons de cinza)
  ColorVisionType.achromatopsia: <double>[
    0.299, 0.587, 0.114, 0, 0,
    0.299, 0.587, 0.114, 0, 0,
    0.299, 0.587, 0.114, 0, 0,
    0.000, 0.000, 0.000, 1, 0,
  ],
};

ColorFilter colorFilterFor(ColorVisionType type) {
  return ColorFilter.matrix(_cvdMatrices[type] ?? _identityMatrix);
}

List<double> matrixFor(ColorVisionType type) => _cvdMatrices[type] ?? _identityMatrix;

String cvdToStorage(ColorVisionType type) => type.name;

ColorVisionType cvdFromStorage(String? value) {
  if (value == null) return ColorVisionType.normal;
  return ColorVisionType.values.firstWhere(
    (e) => e.name == value,
    orElse: () => ColorVisionType.normal,
  );
}

String cvdLabel(ColorVisionType type) {
  switch (type) {
    case ColorVisionType.normal:
      return 'Normal';
    case ColorVisionType.protanopia:
      return 'Protanopia (vermelho)';
    case ColorVisionType.deuteranopia:
      return 'Deuteranopia (verde)';
    case ColorVisionType.tritanopia:
      return 'Tritanopia (azul)';
    case ColorVisionType.achromatopsia:
      return 'Acromatopsia (sem cores)';
  }
}
