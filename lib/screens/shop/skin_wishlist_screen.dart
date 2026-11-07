import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:valorant_thunai/providers/skin_provider.dart';
import 'package:valorant_thunai/providers/skin_wishlist_provider.dart';
import 'package:valorant_thunai/screens/media/skin_details_screen.dart';
import 'package:valorant_thunai/l10n/app_localizations.dart';

class SkinWishlistScreen extends ConsumerWidget {
  const SkinWishlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final wishlist = ref.watch(skinWishlistProvider);
    final skinsMap = ref.watch(skinsMetadataProvider).value ?? {};

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.skinWishlistTitle,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      body: wishlist.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_border, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    l10n.noWishlistedSkinsYet,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.8,
              ),
              itemCount: wishlist.length,
              itemBuilder: (context, index) {
                final skinId = wishlist.elementAt(index);
                final skin = skinsMap[skinId];
                final displayName = skin?.displayName ?? l10n.noName;
                final displayIcon = skin?.displayIcon ?? '';

                return GestureDetector(
                  onTap: skin != null
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SkinDetailsScreen(skin: skin),
                            ),
                          );
                        }
                      : null,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Spacer(),
                              GestureDetector(
                                onTap: () => ref
                                    .read(skinWishlistProvider.notifier)
                                    .remove(skinId),
                                child: const Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: 22,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          if (displayIcon.isNotEmpty)
                            Center(
                              child: Image.network(
                                displayIcon,
                                height: 64,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                          const Spacer(),
                          Text(
                            displayName,
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
