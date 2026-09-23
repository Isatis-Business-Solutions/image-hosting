# Spelleider

Android-app voor de spelleider van het fotospel. De app is alleen voor de
spelleider. Spelers hebben de app niet nodig.

Alles gebeurt op één telefoon. Alle gegevens (spelers, teams, foto's en
uitslagen) blijven lokaal op die telefoon. Er is geen server en geen account.

## Wat kan de app?

| Tabblad | Wat doe je er? |
| --- | --- |
| **Spelers** | Spelers toevoegen met een (koos)naam en eventueel een e-mailadres. |
| **Teams** | Met één knop willekeurig teams van 2 maken. Elk team krijgt zo mogelijk iemand met e-mail. Daarna fijn-tunen: houd een speler ingedrukt en sleep hem op een andere speler om ze te wisselen, bijvoorbeeld om een kind bij een ouder te zetten. Tik op een speler om naam of e-mail aan te passen. Teams zonder e-mail worden rood gemarkeerd. |
| **Foto's** | Foto's maken met de camera of uploaden uit de galerij. Elke foto krijgt een naam. |
| **Potje** | Een potje in 5 stappen (zie hieronder). |
| **Scores** | Het klassement plus alle gespeelde potjes. Tik op een potje om het te corrigeren of te verwijderen. |

### Een potje in 5 stappen

1. **Teams**: kies de twee teams die tegen elkaar spelen.
2. **Foto's**: elk team krijgt een willekeurige foto. De twee teams krijgen altijd verschillende foto's, en foto's die nog niet (of minder vaak) gebruikt zijn krijgen voorrang. Met "Andere foto" trek je opnieuw. Klaar? Druk op **Bevestigen**.
3. **Mail**: per team opent je mailapp met alles klaargezet: het adres, de onderwerpregel, een korte tekst en de foto met onderin een balk met de naam. Jij drukt in de mailapp op verzenden.
4. **Spel**: start zelf de timer (standaard 5 minuten).
   - Is een team eerder klaar? Tik op **Team X klaar**. De tijd wordt vastgelegd en dat team wint.
   - Loopt de tijd af? Dan hoor je een geluid en trilt de telefoon. Daarna vul je de punten in.
   - Pauzeren en opnieuw starten kan ook.
5. **Uitslag**: vul de punten in (het aantal dichtgeklapte kaartjes). De winnaar wordt automatisch gekozen, maar je kunt die zelf aanpassen. Per team staat het vinkje **Telt mee voor het klassement** standaard aan. Zet het uit voor een team dat alleen als tegenstander meespeelt.

**Klassement:** teams die gewonnen hebben staan bovenaan, daarna volgt de snelste tijd, daarna de meeste punten.

### Iets corrigeren

- Elke stap van een potje heeft een knop om terug te gaan of opnieuw te doen: andere teams, andere foto, mail opnieuw openen of de timer resetten.
- "Potje annuleren" gooit het huidige potje weg.
- Een afgerond potje pas je aan via **Scores**: tik op het potje.
- "Alle spelers wissen" (bij Spelers) en "Teams wissen" (bij Teams) beginnen die fase opnieuw.

### Alles verwijderen (na afloop)

Ga naar **Instellingen** (het schuifjes-icoon rechtsboven) en tik **5 keer op
"Spelleider · versie 1.0"**. Dan verschijnt de knop **Alles verwijderen**. Typ
`VERWIJDER` om te bevestigen. Alle spelers, teams, foto's en uitslagen worden
dan gewist.

## Installeren op je telefoon

Je hoeft **geen** ontwikkelaarsopties aan te zetten. Je moet alleen één keer
toestaan dat je telefoon een app van buiten de Play Store installeert.

1. Open op je Android-telefoon de pagina
   **[Releases](https://github.com/Isatis-Business-Solutions/image-hosting/releases/latest)**
   van deze repository.
2. Tik onder "Assets" op **Spelleider.apk** om hem te downloaden.
3. Open het gedownloade bestand, via de melding of via de app *Bestanden* → *Downloads*.
4. Android vraagt of je apps uit deze bron wilt toestaan. Tik op
   **Instellingen**, zet **Toestaan van deze bron** aan (bij Chrome of
   Bestanden) en ga terug.
   Op de meeste telefoons staat dit onder *Instellingen → Apps → Speciale
   app-toegang → Onbekende apps installeren*.
5. Tik op **Installeren**. Zegt Google Play Protect dat de app onbekend is?
   Kies dan **Meer details → Toch installeren**. Dat is normaal voor apps van
   buiten de Play Store.
6. Open **Spelleider**.

**Mail:** voor het versturen heb je een mailapp nodig met je account erin,
bijvoorbeeld Gmail. Kies bij de eerste keer eventueel "Altijd" voor Gmail.

**Bijwerken:** download de nieuwste `Spelleider.apk` en installeer die over de
oude heen. Je gegevens blijven dan bewaard.

## Voor ontwikkelaars

- Gebouwd met Flutter (Dart). De code staat in `lib/`, de tests in `test/`.
- Bij elke push bouwt GitHub Actions (`.github/workflows/build-apk.yml`) de
  app, draait het de tests en publiceert het `Spelleider.apk` als Release.
- Lokaal: `flutter test`, `flutter analyze` en `flutter build apk --release`.
- **Ondertekening:** Android accepteert een update alleen als die met dezelfde
  sleutel is ondertekend. Die sleutel staat **niet** in de repository. GitHub
  Actions haalt hem uit twee geheime waarden (Settings → Secrets and variables
  → Actions):
  - `ANDROID_KEYSTORE_BASE64`: het sleutelbestand (`.jks`), base64-gecodeerd
  - `ANDROID_KEYSTORE_PASSWORD`: het wachtwoord (alias `spelleider`)

  Bewaar een kopie van de sleutel in een wachtwoordkluis. Raak je hem kwijt,
  dan moet je de app verwijderen en opnieuw installeren (en ben je de
  gegevens op de telefoon kwijt). Lokaal zonder `android/key.properties` wordt
  met de debug-sleutel ondertekend.
- **Gegevens:** alles wat in de app wordt ingevoerd (spelers, e-mailadressen,
  foto's, uitslagen) staat alleen in de afgeschermde opslag van de app op de
  telefoon. Er gaat niets naar GitHub of een server.
- Het app-icoon wordt gegenereerd met `dart run tool/make_icon.dart`.
