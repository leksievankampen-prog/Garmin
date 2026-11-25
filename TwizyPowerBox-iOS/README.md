# Twizy PowerBox voor iPhone

iOS-app voor de **PowerBox BT V1.0** (Kenneth Nilsen) in de Renault Twizy.

Het Bluetooth-protocol van deze box is nergens gepubliceerd. Daarom werkt de app in
twee fasen:

1. **Ontdekken:** de app maakt verbinding, luistert op alle kanalen van de box, laat
   al het verkeer zien en kan commando's sturen. Deel de log, dan ligt het protocol op tafel.
2. **Gebruiken:** zodra de box getallen stuurt, vult het dashboard zich vanzelf. Commando's
   die je ontdekt (bijvoorbeeld van stand wisselen) zet je onder een snelknop.

## Wat de app doet

| Tab | Inhoud |
|---|---|
| **Zoeken** | Alle BLE-apparaten. Waarschijnlijke PowerBox-kandidaten (namen als PowerBox/Twizy/HMSoft/BT05, of seriële BLE-services FFE0 / Nordic UART) staan bovenaan met een bliksem. |
| **Dashboard** | Snelheid, accu-meter en kW bovenaan als die velden herkend worden, plus een tegel voor elk getal dat binnenkomt. |
| **Console** | Live verkeer (tekst of hex), commando's versturen (tekst met regeleinde naar keuze, of hex), snelknoppen. |
| **Services** | Alle services en characteristics van de box, met wat ze laatst stuurden. |

- Herkent automatisch: `{"json":1}`, `key=waarde` / `key:waarde` / `KEY 42`, en komma-gescheiden getallen
- Berichten die over meerdere Bluetooth-pakketjes verdeeld zijn, worden weer aan elkaar geplakt
- Onthoudt je box en verbindt automatisch opnieuw zodra hij binnen bereik is
- Deelknop (rechtsboven): de volledige log als tekstbestand, via mail, WhatsApp of Notities
- Vraagt één keer per sessie om bevestiging voordat er iets naar de box gaat

## Op je iPhone zetten

Je hebt een **Mac met Xcode** nodig (gratis in de App Store). Een betaald developer-account
is niet nodig; met je gewone Apple ID werkt de app 7 dagen, daarna installeer je hem opnieuw.

1. Open de map `TwizyPowerBox.swiftpm` in Xcode (dubbelklik, of File > Open).
2. Klik op het project, tab **Signing & Capabilities**, kies bij *Team* je Apple ID
   (Xcode > Settings > Accounts om die toe te voegen).
3. Verander de *Bundle Identifier* in iets unieks, bijvoorbeeld `nl.jouwnaam.twizypowerbox`.
4. Sluit je iPhone aan, kies hem bovenaan als doel en druk op ▶︎.
5. Op de iPhone: Instellingen > Algemeen > VPN en apparaatbeheer > vertrouw je Apple ID.
   Zet op iOS 16+ ook **Ontwikkelaarsmodus** aan (Instellingen > Privacy en beveiliging).

**Geen Mac, wel een iPad?** Open `TwizyPowerBox.swiftpm` in de gratis app *Swift Playgrounds*
op de iPad en druk op Start. De app draait dan op de iPad, met echte Bluetooth.

Let op: de iOS-simulator heeft geen Bluetooth. Test dus op een echt toestel.

## Het protocol achterhalen (stappenplan)

1. Auto aan, app open, tik op de PowerBox in de lijst.
2. Kijk in **Services** welke kanalen er zijn en in **Console** wat er binnenkomt.
3. Stuurt de box niets uit zichzelf? Dan wacht hij op een vraag. Gebruik de officiële
   PowerBox-app en de console daarin om te zien welke commando's die stuurt, en probeer
   die hier (met de auto **stilstaand**).
4. Deel de log (knop rechtsboven) zodat het dashboard en de snelknoppen op het echte protocol
   afgestemd kunnen worden.

## Bestanden

| Bestand | Rol |
|---|---|
| `BLEManager.swift` | Scannen, verbinden, alles ontdekken en afluisteren, schrijven, log |
| `StreamAssembler.swift` | Pakketjes samenvoegen tot berichten (JSON, regels, of na stilte) |
| `TelemetryParser.swift` | Getallen uit berichten halen, veldnamen herkennen |
| `Models.swift` | Datatypes, PowerBox-herkenning, hex-invoer |
| `ScanView.swift`, `DeviceView.swift`, `ConsoleView.swift`, `ServicesView.swift` | Schermen |
