/// Matrizes de cor compartilhadas para filtros globais.
///
/// A matriz abaixo segue a fórmula de luminância relativa definida pelo WCAG
/// 2.1 (Anexo G, equações G-17 e G-18) e pelos primários da recomendação
/// ITU-R BT.709 (também descritos por Poynton, 2012). Ela é útil para simular
/// modos de alto contraste/tons de cinza consistentes com a bibliografia.
const List<double> kRelativeLuminanceGrayscaleMatrix = <double>[
  _lumR,
  _lumG,
  _lumB,
  0,
  0,
  _lumR,
  _lumG,
  _lumB,
  0,
  0,
  _lumR,
  _lumG,
  _lumB,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
];

const double _lumR = 0.2126; // R* componente sRGB/Rec.709 (W3C, WCAG 2.1)
const double _lumG = 0.7152; // G* componente sRGB/Rec.709
const double _lumB = 0.0722; // B* componente sRGB/Rec.709
