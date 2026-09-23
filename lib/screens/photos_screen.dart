import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/page.dart';

class PhotosScreen extends StatelessWidget {
  const PhotosScreen({super.key});

  Future<void> _add(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Glass(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera_rounded,
                      color: AppColors.yellow),
                  title: const Text('Foto maken'),
                  onTap: () => Navigator.pop(c, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded,
                      color: AppColors.yellow),
                  title: const Text('Uploaden uit galerij'),
                  subtitle: const Text('Je kunt meerdere foto\'s kiezen'),
                  onTap: () => Navigator.pop(c, ImageSource.gallery),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (source == null) return;

    final picker = ImagePicker();
    List<XFile> files;
    try {
      if (source == ImageSource.camera) {
        final f = await picker.pickImage(
            source: source, maxWidth: 2048, maxHeight: 2048, imageQuality: 90);
        files = f == null ? [] : [f];
      } else {
        files = await picker.pickMultiImage(
            maxWidth: 2048, maxHeight: 2048, imageQuality: 90);
      }
    } catch (e) {
      if (context.mounted) toast(context, 'Kon geen foto ophalen: $e');
      return;
    }

    for (var i = 0; i < files.length; i++) {
      if (!context.mounted) return;
      final name = await _askName(context, files[i].path,
          counter: files.length > 1 ? '${i + 1} van ${files.length}' : null);
      if (name == null) continue;
      await store.addPhoto(files[i].path, name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: "Foto's",
      subtitle: () => "${store.photos.length} foto's in de pool",
      floating: FloatingActionButton.extended(
        onPressed: () => _add(context),
        icon: const Icon(Icons.add_a_photo_rounded),
        label: const Text('Foto',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      builder: (context) {
        if (store.photos.isEmpty) {
          return const [
            EmptyState(
              icon: Icons.add_a_photo_rounded,
              title: "Nog geen foto's",
              text: 'Maak een foto of upload er een uit je galerij. Elke foto '
                  'krijgt een naam die op de foto en in de mail komt.',
            ),
          ];
        }
        final usage = store.photoUsage;
        return [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.8,
            children: [
              for (final p in store.photos)
                PhotoTile(photo: p, uses: usage[p.id] ?? 0),
            ],
          ),
        ];
      },
    );
  }
}

class PhotoTile extends StatelessWidget {
  const PhotoTile({super.key, required this.photo, required this.uses});

  final Photo photo;
  final int uses;

  @override
  Widget build(BuildContext context) {
    return Glass(
      padding: EdgeInsets.zero,
      onTap: () => _showDetail(context, photo),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(21)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PhotoImage(path: photo.path),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Pill(uses == 0 ? 'nieuw' : '${uses}x',
                        color: uses == 0 ? AppColors.ok : AppColors.yellow),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Text(photo.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class PhotoImage extends StatelessWidget {
  const PhotoImage({super.key, required this.path, this.fit = BoxFit.cover});

  final String path;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.file(
      File(path),
      fit: fit,
      cacheWidth: fit == BoxFit.cover ? 600 : null,
      errorBuilder: (_, _, _) => Container(
        color: AppColors.grey,
        child: const Icon(Icons.broken_image_rounded, color: AppColors.muted),
      ),
    );
  }
}

Future<String?> _askName(BuildContext context, String path,
    {String? initial, String? counter}) {
  final ctrl = TextEditingController(text: initial ?? '');
  final formKey = GlobalKey<FormState>();
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (c) => AlertDialog(
      title: Text(counter == null ? 'Naam van de foto' : 'Naam ($counter)'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                  height: 180, width: 280, child: PhotoImage(path: path)),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Naam'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Vul een naam in' : null,
              onFieldSubmitted: (_) {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(c, ctrl.text.trim());
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(initial == null ? 'Overslaan' : 'Annuleren')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.pop(c, ctrl.text.trim());
            }
          },
          child: const Text('Opslaan'),
        ),
      ],
    ),
  );
}

Future<void> _showDetail(BuildContext context, Photo photo) async {
  await showDialog<void>(
    context: context,
    builder: (c) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Glass(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.55),
                child: PhotoImage(path: photo.path, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 12),
            Text(photo.name,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Naam'),
                    onPressed: () async {
                      final n = await _askName(c, photo.path,
                          initial: photo.name);
                      if (n != null) store.renamePhoto(photo, n);
                      if (c.mounted) Navigator.pop(c);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Verwijder'),
                    onPressed: () async {
                      if (await confirmDialog(c,
                          title: 'Foto verwijderen?',
                          message: '"${photo.name}" wordt uit de pool '
                              'verwijderd.',
                          confirm: 'Verwijderen',
                          danger: true)) {
                        await store.removePhoto(photo);
                        if (c.mounted) Navigator.pop(c);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
