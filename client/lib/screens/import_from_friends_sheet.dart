import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:trip_planner/services/trip_invite_service.dart';

class ImportFromFriendsSheet extends StatefulWidget {
  const ImportFromFriendsSheet({super.key});

  @override
  State<ImportFromFriendsSheet> createState() => _ImportFromFriendsSheetState();
}

class _ImportFromFriendsSheetState extends State<ImportFromFriendsSheet> {
  final TextEditingController _codeController = TextEditingController();
  bool _isImporting = false;
  String? _errorText;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  String _formatCode(String value) {
    final cleaned =
        value.trim().toUpperCase().replaceAll(' ', '').replaceAll('-', '');

    if (cleaned.isEmpty) return '';

    if (cleaned.startsWith('YTR')) {
      final body = cleaned.substring(3);
      return body.isEmpty ? 'YTR-' : 'YTR-$body';
    }

    return 'YTR-$cleaned';
  }

  Future<void> _pasteCode() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';

    if (text.trim().isEmpty) return;

    setState(() {
      _codeController.text = _formatCode(text);
      _errorText = null;
    });
  }

  Future<void> _importTrip() async {
    if (_isImporting) return;

    final code = _formatCode(_codeController.text);

    if (code.length < 8) {
      setState(() {
        _errorText = 'Enter a valid invite code';
      });
      return;
    }

    setState(() {
      _isImporting = true;
      _errorText = null;
    });

    try {
      final savedTripId = await TripInviteService.importTripByInviteCode(code);

      if (!mounted) return;

      if (savedTripId == null) {
        setState(() {
          _isImporting = false;
          _errorText = 'Invalid or expired invite code';
        });
        return;
      }

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Trip imported successfully: $savedTripId'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isImporting = false;
        _errorText = 'Unable to import trip. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.88,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Import Trip',
                              style: TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.0,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Enter your friend’s Yatrik code',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.black,
                            size: 32,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 36),
                  Center(
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F9FF),
                        borderRadius: BorderRadius.circular(38),
                        border: Border.all(
                          color: const Color(0xFFBCE0FD),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.travel_explore_rounded,
                        color: Color(0xFF1E88E5),
                        size: 78,
                      ),
                    ),
                  ),
                  const SizedBox(height: 38),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FA),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: Colors.grey.shade200,
                        width: 1.3,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FRIEND SHARE CODE',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.4,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _codeController,
                          textCapitalization: TextCapitalization.characters,
                          keyboardType: TextInputType.text,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z0-9\- ]'),
                            ),
                          ],
                          onChanged: (_) {
                            if (_errorText != null) {
                              setState(() {
                                _errorText = null;
                              });
                            }
                          },
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            color: Colors.black,
                          ),
                          decoration: InputDecoration(
                            hintText: 'YTR-8K4P2Q',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade300,
                              fontWeight: FontWeight.w900,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 18,
                            ),
                            suffixIcon: IconButton(
                              onPressed: _pasteCode,
                              icon: const Icon(
                                Icons.content_paste_rounded,
                                color: Color(0xFF1E88E5),
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        if (_errorText != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _errorText!,
                            style: TextStyle(
                              color: Colors.red.shade600,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: Colors.orange.shade700,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Ask your friend to open their trip and tap Share. Then enter the code here.',
                            style: TextStyle(
                              color: Colors.orange.shade900,
                              fontSize: 13,
                              height: 1.35,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _isImporting ? null : _importTrip,
                    child: Container(
                      width: double.infinity,
                      height: 76,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(38),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.16),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _isImporting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Import Trip Plan',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.3,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
