import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../widgets/curl_book_view.dart';
import '../widgets/game_frame.dart';
import '../widgets/book_view.dart'; // só para reutilizar a página de texto
import '../theme/theme_provider.dart';

class BookDemoScreen extends StatelessWidget {
  const BookDemoScreen({super.key});

  static const String _lorem =
      '''Lorem ipsum dolor sit amet, consectetur adipiscing elit. Integer a pulvinar nibh. Suspendisse potenti. Aliquam dapibus, tortor in dictum ultricies, velit ipsum ultricies massa, id viverra sem leo nec orci. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Proin id condimentum enim. Cras sed sollicitudin dui. Maecenas viverra, ex in tempor finibus, nibh lacus hendrerit magna, at faucibus dui tellus sit amet elit. Donec ultrices rhoncus metus, sit amet tincidunt mi tristique vitae. Integer ac rhoncus mi. Sed euismod, quam in laoreet hendrerit, erat risus varius arcu, non posuere felis lorem et lectus.

Curabitur non risus nisi. Donec condimentum mauris et ex scelerisque, vitae placerat dui imperdiet. Nulla facilisi. Integer interdum mi leo, sit amet posuere sem pretium at. Vivamus vitae quam nec dui porttitor mattis. Aenean eleifend, justo et cursus fermentum, massa lorem aliquet ex, id porttitor dui est id nisl. Proin molestie fringilla sem, nec facilisis odio volutpat vel.

Phasellus dictum, ipsum quis aliquet viverra, justo leo iaculis lorem, et convallis metus lorem id urna. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia curae; Cras sed erat euismod, porttitor nibh in, dignissim augue. Integer convallis, nulla at lobortis condimentum, massa justo gravida metus, sit amet vulputate justo dolor sed arcu. Etiam varius congue justo, vitae suscipit velit tincidunt at.''';

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const Center(
        child: Text(
          'Capa',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
        ),
      ),
      const BookTextPage(_lorem),
      const BookTextPage(_lorem),
      const BookTextPage(_lorem),
      const BookTextPage(_lorem),
    ];

    final reduceMotion = context.watch<ThemeProvider>().reduceMotion;

    final Widget bookWidget = reduceMotion
        ? BookView(
            pages: pages,
            pagePadding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
            flipDuration: const Duration(milliseconds: 100),
          )
        : CurlBookView(
            pages: pages,
            aspectRatio: 3 / 2,
            outerPadding: const EdgeInsets.all(1),
            pagePadding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
          );

    return GameScaffold(
      title: 'Livro (Demo)',
      panelPadding: const EdgeInsets.all(4),
      child: bookWidget,
    );
  }
}
