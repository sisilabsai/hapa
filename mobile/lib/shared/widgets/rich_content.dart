import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Renders post body text with clickable URLs, coloured #hashtags,
/// bold **text**, italic _text_, and @mention highlights.
class RichContent extends StatelessWidget {
  final String text;
  final TextStyle? baseStyle;
  final Color accentColor;
  final int? maxLines;
  final TextOverflow overflow;
  final void Function(String tag)? onHashtagTap;
  final void Function(String username)? onMentionTap;

  const RichContent({
    super.key,
    required this.text,
    this.baseStyle,
    this.accentColor = const Color(0xFFC8862A),
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.onHashtagTap,
    this.onMentionTap,
  });

  static final _urlRegex = RegExp(
    r'https?://[^\s]+|www\.[^\s]+',
    caseSensitive: false,
  );
  static final _hashtagRegex = RegExp(r'#(\w+)');
  static final _mentionRegex = RegExp(r'@(\w+)');
  static final _boldRegex = RegExp(r'\*\*(.+?)\*\*');
  static final _italicRegex = RegExp(r'(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)');

  @override
  Widget build(BuildContext context) {
    final base = (baseStyle ?? DefaultTextStyle.of(context).style).copyWith();
    final spans = _parse(text, base);
    return Text.rich(
      TextSpan(children: spans),
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  List<InlineSpan> _parse(String input, TextStyle base) {
    // Combined token regex — order matters
    final tokenRegex = RegExp(
      r'(\*\*(.+?)\*\*)|(\*(?!\*)(.+?)\*(?!\*))|'
      r'(https?://[^\s]+|www\.[^\s]+)|'
      r'(#\w+)|(@\w+)',
      caseSensitive: false,
    );

    final spans = <InlineSpan>[];
    int last = 0;

    for (final match in tokenRegex.allMatches(input)) {
      if (match.start > last) {
        spans.add(TextSpan(text: input.substring(last, match.start), style: base));
      }

      final full = match.group(0)!;

      if (full.startsWith('**')) {
        // Bold
        final inner = match.group(2) ?? full.replaceAll('**', '');
        spans.add(TextSpan(
          text: inner,
          style: base.copyWith(fontWeight: FontWeight.w800),
        ));
      } else if (full.startsWith('*')) {
        // Italic
        final inner = match.group(4) ?? full.replaceAll('*', '');
        spans.add(TextSpan(
          text: inner,
          style: base.copyWith(fontStyle: FontStyle.italic),
        ));
      } else if (_urlRegex.hasMatch(full)) {
        // Clickable URL
        final url = full.startsWith('www.') ? 'https://$full' : full;
        final displayText = _shortenUrl(full);
        spans.add(TextSpan(
          text: displayText,
          style: base.copyWith(
            color: const Color(0xFF3B82F6),
            decoration: TextDecoration.underline,
            decorationColor: const Color(0xFF3B82F6),
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => _launchUrl(url),
        ));
      } else if (full.startsWith('#')) {
        // Hashtag
        spans.add(TextSpan(
          text: full,
          style: base.copyWith(
            color: accentColor,
            fontWeight: FontWeight.w600,
          ),
          recognizer: onHashtagTap != null
              ? (TapGestureRecognizer()..onTap = () => onHashtagTap!(full.substring(1)))
              : null,
        ));
      } else if (full.startsWith('@')) {
        // Mention
        spans.add(TextSpan(
          text: full,
          style: base.copyWith(
            color: const Color(0xFF6366F1),
            fontWeight: FontWeight.w600,
          ),
          recognizer: onMentionTap != null
              ? (TapGestureRecognizer()..onTap = () => onMentionTap!(full.substring(1)))
              : null,
        ));
      } else {
        spans.add(TextSpan(text: full, style: base));
      }

      last = match.end;
    }

    if (last < input.length) {
      spans.add(TextSpan(text: input.substring(last), style: base));
    }

    return spans;
  }

  String _shortenUrl(String url) {
    try {
      final clean = url.replaceFirst(RegExp(r'https?://'), '').replaceFirst('www.', '');
      return clean.length > 35 ? '${clean.substring(0, 33)}…' : clean;
    } catch (_) {
      return url;
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
