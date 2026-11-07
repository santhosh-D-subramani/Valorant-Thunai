import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:valorant_thunai/providers/auth_provider.dart';
import 'package:valorant_thunai/screens/auth/riot_login_screen.dart';
import 'package:valorant_thunai/l10n/app_localizations.dart';

Future<void> showAccountSwitcherBottomSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  HapticFeedback.mediumImpact();
  await showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (bottomSheetContext) {
      return const AccountSwitcherBottomSheet();
    },
  );
}

class AccountSwitcherBottomSheet extends ConsumerWidget {
  const AccountSwitcherBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authProvider);
    final users = authState.allUsers;
    final activeIndex = authState.activeUserIndex;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Text(
                    l10n?.accountsSectionHeader ?? 'Accounts',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${users.length}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.35,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: users.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    thickness: 1,
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.3,
                    ),
                  ),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final isActive = index == activeIndex;

                    return Material(
                      color: isActive
                          ? theme.colorScheme.primaryContainer.withValues(
                              alpha: 0.25,
                            )
                          : Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          if (!isActive) {
                            HapticFeedback.selectionClick();
                            ref
                                .read(authProvider.notifier)
                                .switchAccount(index);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  user.gameName != null &&
                                          user.gameName!.isNotEmpty
                                      ? 'Switched to ${user.gameName}'
                                      : 'Switched account',
                                ),
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          }
                          Navigator.of(context).pop();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isActive
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.outlineVariant,
                                    width: isActive ? 2.5 : 1,
                                  ),
                                ),
                                child: ClipOval(
                                  child: Image.network(
                                    user.playerCardId != null &&
                                            user.playerCardId!.isNotEmpty
                                        ? 'https://media.valorant-api.com/playercards/${user.playerCardId}/displayicon.png'
                                        : 'https://media.valorant-api.com/playercards/9fb3f4ab-4c11-1a3b-955e-5e9ad13289f3/displayicon.png',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Container(
                                      color: theme
                                          .colorScheme
                                          .surfaceContainerHighest,
                                      child: Icon(
                                        Icons.person,
                                        size: 24,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            user.gameName != null &&
                                                    user.gameName!.isNotEmpty
                                                ? user.gameName!
                                                : 'Account ${index + 1}',
                                            style: GoogleFonts.inter(
                                              fontWeight: isActive
                                                  ? FontWeight.bold
                                                  : FontWeight.w600,
                                              fontSize: 15,
                                              color: isActive
                                                  ? theme.colorScheme.primary
                                                  : theme.colorScheme.onSurface,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (user.tagline != null &&
                                            user.tagline!.isNotEmpty) ...[
                                          const SizedBox(width: 4),
                                          Text(
                                            '#${user.tagline}',
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        if (user.level != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 1,
                                            ),
                                            decoration: BoxDecoration(
                                              color: theme
                                                  .colorScheme
                                                  .surfaceContainerHighest,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'Lvl ${user.level}',
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color: theme
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                            ),
                                          ),
                                        if (user.level != null)
                                          const SizedBox(width: 6),
                                        Text(
                                          user.region.toUpperCase(),
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (isActive)
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: theme.colorScheme.primary,
                                  size: 22,
                                )
                              else
                                Icon(
                                  Icons.radio_button_unchecked_rounded,
                                  color: theme.colorScheme.outlineVariant,
                                  size: 22,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.35,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.person_add_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      title: Text(
                        l10n?.loginWithRiot ?? 'Add Riot Account',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const RiotLoginScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
