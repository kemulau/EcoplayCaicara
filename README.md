# Ecoplay Caiçara

Ecoplay Caiçara é um aplicativo Flutter focado em educação ambiental e acessibilidade. O projeto atualmente inclui telas de cadastro de jogador e uma home com cartões para diferentes jogos temáticos.

## Estrutura do projeto

O código Flutter encontra-se no diretório [`ecoplaycaicara/`](./ecoplaycaicara). Os principais componentes são:

- `lib/`: widgets, temas e telas da aplicação.
  - `screens/cadastro.dart`: formulário de cadastro de jogador com diversas opções de acessibilidade.
  - `screens/home.dart`: exibe cartões dos jogos "Maré Responsa", "Missão Reciclagem", "Toca do Caranguejo" e "Trilha da Fauna".
  - `theme/retro.dart`: tema retro personalizado.
  - `widgets/pixel_button.dart`: botão estilizado em pixel art.
- `assets/`: imagens de fundo, avatares e artes dos cartões.
- `pubspec.yaml`: dependências e configuração do Flutter.

## Dependências principais

- [flutter](https://flutter.dev)
- [google_fonts](https://pub.dev/packages/google_fonts)
- [shared_preferences](https://pub.dev/packages/shared_preferences)
- [provider](https://pub.dev/packages/provider)
- [form_field_validator](https://pub.dev/packages/form_field_validator)

## Como executar

1. Instale o Flutter (versão >= 3.8.1).
2. Clone este repositório e acesse a pasta do projeto:

```bash
git clone <repo-url>
cd EcoplayCaicara/ecoplaycaicara
```

3. Baixe as dependências:

```bash
flutter pub get
```

4. Execute em um dispositivo ou emulador disponível:

```bash
flutter run
```

Também é possível compilar para web usando `flutter run -d chrome` ou `flutter build web`.

## Contribuição

Contribuições são bem-vindas! Sinta-se livre para abrir _issues_ ou enviar _pull requests_ com melhorias e correções.

## Licença

Este projeto não possui uma licença definida.
