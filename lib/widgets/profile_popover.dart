import 'package:flutter/material.dart';

class ProfilePopover extends StatelessWidget {
  const ProfilePopover({
    super.key,
    required this.name,
    required this.email,
    required this.initialLetter,
    required this.accentColor,
    this.manageLabel = 'Administrar cuenta',
    this.logoutLabel = 'Cerrar sesión',
  });

  final String name;
  final String email;
  final String initialLetter;
  final Color accentColor;
  final String manageLabel;
  final String logoutLabel;

  @override
  Widget build(BuildContext context) {
    final displayName = name.trim().isEmpty ? email.trim() : name.trim();
    final greetingName = displayName.isEmpty
        ? '¡Hola!'
        : '¡Hola, ${displayName.trim()}!';
    final letter =
        (initialLetter.trim().isNotEmpty
                ? initialLetter.trim().substring(0, 1)
                : (displayName.isNotEmpty ? displayName.substring(0, 1) : '?'))
            .toUpperCase();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.only(
        left: 24,
        right: 16,
        top: 64,
        bottom: 24,
      ),
      child: Align(
        alignment: Alignment.topRight,
        child: Material(
          elevation: 12,
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: accentColor.withOpacity(0.12),
                        child: CircleAvatar(
                          radius: 24,
                          backgroundColor: accentColor,
                          child: Text(
                            letter,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 24,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              email,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              greetingName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cerrar',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop('manage'),
                      child: Text(
                        manageLabel,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade600,
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop('logout'),
                      child: Text(
                        logoutLabel,
                        style: const TextStyle(fontWeight: FontWeight.w600),
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
