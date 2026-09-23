import 'package:flutter_email_sender/flutter_email_sender.dart';

import '../models.dart';
import 'photo_composer.dart';

/// Opent de mailapp met de foto (met naam-balk) klaargezet voor een team.
/// Gooit een [FlutterEmailSenderException] als er geen mailapp is.
Future<void> openMailForSide({
  required Side side,
  required List<String> recipients,
  required String photoPath,
}) async {
  final name = side.photoName ?? 'Foto';
  final attachment = await composePhotoWithName(photoPath, name);
  final hi = side.playerNames.join(' & ');
  await FlutterEmailSender.send(Email(
    recipients: recipients,
    subject: 'Jouw foto: $name',
    body: 'Hoi $hi,\n\n'
        'Dit is jullie foto: $name\n\n'
        'Veel succes!',
    attachmentPaths: [attachment],
  ));
}
