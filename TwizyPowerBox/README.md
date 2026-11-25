# Twizy PowerBox (Garmin Connect IQ)

Een watch-app die via Bluetooth Low Energy verbinding maakt met de PowerBox BT
in een Renault Twizy en live autodata op je Garmin toont.

## Wat je ziet

| Pagina | Inhoud |
|---|---|
| 1. Dashboard | Snelheid (groot), SOC-ring rond de rand, vermogen in kW (oranje = verbruik, groen = recuperatie/laden) |
| 2. Details | Spanning, stroom, vermogen, motortemperatuur, SOC |
| 3. Diagnose | BLE-status, apparaatnaam, RSSI, tellers, CAN-leeftijd en het **laatste ruwe bericht** van de box |

Knoppen: **UP/DOWN** (of vegen) = andere pagina, **START** (of tikken) = opnieuw zoeken naar de box, **BACK** = afsluiten.

## Protocol

De app volgt het open protocol van de PowerBox BT-firmware uit
[rakkipe/Twizy-pb-bt-fixed](https://github.com/rakkipe/Twizy-pb-bt-fixed):

- BLE-naam `TwizyPB` (in te stellen), Nordic UART Service `6E400001-B5A3-F393-E0A9-E50E24DCCA9E`
- Notify op TX `6E400003-...`, ongeveer 5x per seconde één plat JSON-object zonder regeleinde:

  ```json
  {"v":57.3,"i":12.5,"p":716.2,"soc":81.5,"spd":42.1,"tmp":38,"valid":true,"frames":12345,"can_age_ms":12}
  ```

  | Veld | Betekenis |
  |---|---|
  | `v` | accuspanning (V) |
  | `i` | stroom (A), positief = ontladen, negatief = laden/recuperatie |
  | `p` | vermogen (W) |
  | `soc` | laadtoestand (%) |
  | `spd` | snelheid (km/h) |
  | `tmp` | motortemperatuur (°C) |
  | `valid` | BMS-data geldig |
  | `frames`, `can_age_ms` | CAN-frameteller en ms sinds laatste CAN-frame |

- Een bericht (~110 bytes) past niet in één standaard BLE-pakket (20 bytes). De app
  buffert daarom de fragmenten tot een volledige `{...}` binnen is, en herstelt zichzelf
  als er een fragment wegvalt.
- **Alleen lezen.** De firmware negeert schrijfopdrachten (CAN staat in listen-only),
  dus deze app stuurt geen commando's naar de auto. Tunen (vermogen, topsnelheid,
  recuperatie) zit niet in dit protocol.

### Heb je een andere (commerciële) PowerBox?

Andere PowerBox-varianten gebruiken mogelijk een eigen, ongedocumenteerd protocol.
Zo kom je erachter wat jouw box spreekt:

1. Installeer **nRF Connect** op je telefoon en scan in de auto.
2. Noteer de naam, de service-UUID's en wat er binnenkomt op de notify-characteristic.
3. Komt de box als Nordic UART binnen maar met een andere naam, stel die naam dan in bij de
   app-instellingen (Connect IQ-app op je telefoon). Pagina 3 laat het ruwe bericht zien.
4. Is het formaat anders, dan hoeft alleen `source/PowerBoxProtocol.mc` aangepast te worden.

## Bouwen en installeren

Nodig: [Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/) (3.2 of nieuwer),
een developer key en Visual Studio Code met de Monkey C-extensie.

```bash
# Developer key (eenmalig)
openssl genrsa -out developer_key.pem 4096
openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem -out developer_key.der -nocrypt

# Bouwen voor bijvoorbeeld een Fenix 7
monkeyc -f monkey.jungle -d fenix7 -y developer_key.der -o bin/TwizyPowerBox.prg

# Op het horloge: kopieer de .prg via USB naar GARMIN/APPS/
```

### Testen zonder auto

Zet in de instellingen **Demomodus** aan. De app genereert dan een rit (optrekken,
cruisen, remmen met recuperatie, stilstaan) en stuurt die door dezelfde parser, in
stukjes van 20 bytes zoals echte BLE. Zo werkt de app ook in de simulator, die zonder
nRF52-dongle geen BLE heeft.

Unit tests (parser en fragmentherstel):

```bash
monkeyc -f monkey.jungle -d fenix7 -y developer_key.der -o bin/test.prg -t
monkeydo bin/test.prg fenix7 -t
```

## Ondersteunde horloges

Fenix 7 / 7S / 7X, Epix 2, Forerunner 255 / 265 / 955 / 965, Venu 2 / 3, Vivoactive 5.
Andere horloges met Connect IQ 3.2+ en BLE-ondersteuning kun je toevoegen in `manifest.xml`.

## Bestanden

| Bestand | Rol |
|---|---|
| `source/PowerBoxBle.mc` | BLE: profiel registreren, scannen, koppelen, notificaties aanzetten |
| `source/PowerBoxProtocol.mc` | Fragmenten samenvoegen en JSON parsen |
| `source/TwizyModel.mc` | Laatste waarden en verbindingsstatus |
| `source/TwizyView.mc` | De drie schermen |
| `source/DemoSource.mc` | Gesimuleerde box voor testen |
| `source/ProtocolTests.mc` | Unit tests |
