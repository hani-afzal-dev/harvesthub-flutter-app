import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/page_header.dart';
import '../../widgets/app_snackbar.dart';

const Color _brand = Color(0xFF3B6D11);
const Color _brandDark = Color(0xFF2E4A0F);
const Color _textMain = Color(0xFF22301A);
const Color _textMuted = Color(0xFF6B7A5E);
const Color _tint = Color(0xFFEFF3EA);

class ContactUsScreen extends StatefulWidget {
  const ContactUsScreen({super.key});

  @override
  State<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends State<ContactUsScreen> {
  static const _supportEmail = 'harvesthub.support@gmail.com';
  static const _supportPhone = '0331 2666892';
  static const _supportPhoneDial = '+923312666892';
  static const _officeAddress =
      'Aptech Latifabad Centre, Unit No. 2, Latifabad, Hyderabad';
  static const _feedbackLimit = 1000;

  final _feedbackController = TextEditingController();
  String? _error;
  bool _sending = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _launch(Uri uri, String failMessage) async {
    var opened = false;
    try {
      opened = await launchUrl(uri);
    } catch (_) {
      opened = false;
    }
    if (opened || !mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(appSnackBar(failMessage, tone: SnackTone.error));
  }

  Future<void> _sendFeedback() async {
    if (_sending) return;
    final message = _feedbackController.text.trim();
    if (message.isEmpty) {
      setState(() => _error = 'Write your feedback before sending.');
      return;
    }
    if (message.length < 10) {
      setState(() => _error = 'Tell us a little more, at least 10 characters.');
      return;
    }
    setState(() {
      _error = null;
      _sending = true;
    });

    final uri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      query:
          'subject=${Uri.encodeComponent('HarvestHub feedback')}&body=${Uri.encodeComponent(message)}',
    );
    var launched = false;
    try {
      launched = await launchUrl(uri);
    } catch (_) {
      launched = false;
    }
    if (!mounted) return;
    setState(() => _sending = false);
    if (launched) {
      _feedbackController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar('Opening your email app to send this feedback.',
            tone: SnackTone.success),
      );
    } else {
      setState(() => _error =
          'No email app found on this device. Email us at $_supportEmail.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F3),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const PageHeader(title: 'Contact Us'),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF5A9A1F),
                              _brand,
                              Color(0xFF2A4A0C)
                            ],
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.support_agent_rounded,
                                  color: Colors.white, size: 28),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "We're here to help",
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Questions about an order, a farmer or the app? Reach out any time.',
                                    style: TextStyle(
                                        fontSize: 13,
                                        height: 1.4,
                                        color: Colors.white
                                            .withValues(alpha: 0.9)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const _SectionLabel('GET IN TOUCH'),
                      _Card(
                        child: Column(
                          children: [
                            _ContactTile(
                              key: const ValueKey('contact_email_tile'),
                              icon: Icons.mail_outline_rounded,
                              title: 'Email us',
                              value: _supportEmail,
                              onTap: () => _launch(
                                Uri(scheme: 'mailto', path: _supportEmail),
                                'No email app found. Our address is $_supportEmail.',
                              ),
                            ),
                            if (_supportPhone.isNotEmpty) ...[
                              const Divider(height: 1, indent: 64),
                              _ContactTile(
                                key: const ValueKey('contact_phone_tile'),
                                icon: Icons.phone_outlined,
                                title: 'Call us',
                                value: _supportPhone,
                                onTap: () => _launch(
                                  Uri(scheme: 'tel', path: _supportPhoneDial),
                                  'Calling is not available on this device. Our number is $_supportPhone.',
                                ),
                              ),
                            ],
                            if (_officeAddress.isNotEmpty) ...[
                              const Divider(height: 1, indent: 64),
                              _ContactTile(
                                key: const ValueKey('contact_address_tile'),
                                icon: Icons.place_outlined,
                                title: 'Visit our office',
                                value: _officeAddress,
                                onTap: () => _launch(
                                  Uri.https('www.google.com', '/maps/search/',
                                      {'api': '1', 'query': _officeAddress}),
                                  'Could not open maps. Our office is at $_officeAddress.',
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const _SectionLabel('SEND FEEDBACK'),
                      _Card(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              "Tell us what's working, what isn't, or what you'd like to see next.",
                              style: TextStyle(
                                  fontSize: 13, height: 1.4, color: _textMuted),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              key: const ValueKey('contact_feedback_field'),
                              controller: _feedbackController,
                              minLines: 4,
                              maxLines: 8,
                              maxLength: _feedbackLimit,
                              textCapitalization: TextCapitalization.sentences,
                              onChanged: (_) {
                                if (_error != null) {
                                  setState(() => _error = null);
                                }
                              },
                              decoration: InputDecoration(
                                labelText: 'Your feedback',
                                alignLabelWithHint: true,
                                errorText: _error,
                                errorMaxLines: 2,
                                filled: true,
                                fillColor: _tint,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                      color: _brand, width: 1.5),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 52,
                              child: FilledButton.icon(
                                key: const ValueKey('contact_send_button'),
                                onPressed: _sending ? null : _sendFeedback,
                                style: FilledButton.styleFrom(
                                  backgroundColor: _brand,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                ),
                                icon: _sending
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white),
                                      )
                                    : const Icon(Icons.send_rounded, size: 18),
                                label: const Text('Send feedback',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.9,
            color: _textMuted),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _Card({required this.child, this.padding = EdgeInsets.zero});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: _brandDark.withValues(alpha: 0.07),
              blurRadius: 18,
              offset: const Offset(0, 6))
        ],
      ),
      child: child,
    );
  }
}

class _ContactTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;

  const _ContactTile(
      {super.key,
      required this.icon,
      required this.title,
      required this.value,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    final action = onTap;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: action,
        borderRadius: BorderRadius.circular(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                      color: _tint, borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, size: 20, color: _brand),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style:
                              const TextStyle(fontSize: 12, color: _textMuted)),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _textMain),
                      ),
                    ],
                  ),
                ),
                if (action != null)
                  const Icon(Icons.chevron_right_rounded,
                      color: Color(0xFFA3AC9A)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
