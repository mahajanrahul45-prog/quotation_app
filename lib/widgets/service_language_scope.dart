import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class ServiceLanguageScope extends StatelessWidget {
  const ServiceLanguageScope({
    super.key,
    required this.code,
    required this.child,
  });
  final String code;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Localizations.override(
      context: context,
      locale: Locale(code == 'hi' ? 'hi' : 'en'),
      delegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      child: Theme(
        data: code == 'hi' || code == 'en_hi'
            ? theme.copyWith(
                textTheme: theme.textTheme.apply(fontFamily: 'NotoService'),
                primaryTextTheme: theme.primaryTextTheme.apply(
                  fontFamily: 'NotoService',
                ),
              )
            : theme,
        child: child,
      ),
    );
  }
}
