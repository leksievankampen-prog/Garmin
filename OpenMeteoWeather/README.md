# Open-Meteo Weer voor Garmin fēnix 7X (Solar)

Een Connect IQ watch-app (met glance) die het weer op je huidige locatie toont via de gratis
[Open-Meteo API](https://open-meteo.com/). Geen API-sleutel nodig.

## Wat je ziet

| Scherm | Inhoud |
| --- | --- |
| **Glance** (widgetlijst) | Icoon, huidige temperatuur, omschrijving, max/min van vandaag |
| **Pagina 1: Nu** | Groot icoon + temperatuur, omschrijving, gevoelstemperatuur, wind (met richtingspijl), luchtvochtigheid, max/min |
| **Pagina 2: Per uur** | De komende 6 uur: tijd, icoon, temperatuur, neerslagkans |
| **Pagina 3: Komende dagen** | 5 dagen: dag, icoon, max/min, neerslagkans |

Bediening:

* **UP / DOWN** (of vegen): wisselen tussen pagina's
* **START** (of tikken): opnieuw ophalen
* **BACK**: afsluiten

De laatst opgehaalde voorspelling wordt bewaard. Zonder telefoonverbinding zie je dus nog steeds
de vorige data, met "Offline" en het tijdstip van de laatste update bovenin.

Taal volgt het horloge (Nederlands of Engels). Via de Connect IQ-app op je telefoon kun je
de eenheden instellen: °C/°F en km/u, m/s, mph of knopen.

## Hoe het werkt

1. Locatie: eerst de laatst bekende GPS-positie van het horloge, anders de positie van de vorige
   keer. Is die niet vers, dan vraagt de app eenmalig een nieuwe GPS-fix en haalt opnieuw op als je
   meer dan ongeveer 5 km verplaatst bent.
2. Het verzoek gaat via Bluetooth naar de Garmin Connect-app op je telefoon, die het doorstuurt naar
   `api.open-meteo.com`. De fēnix 7X Solar heeft geen wifi, dus je telefoon moet verbonden zijn.
3. Het antwoord wordt teruggebracht tot een klein data-object, opgeslagen in `Application.Storage`
   en getekend. Alle weericonen zijn vectortekeningen, dus er zijn geen plaatjes nodig.

## Bouwen en installeren

1. Installeer [Visual Studio Code](https://code.visualstudio.com/) en de extensie **Monkey C** van Garmin.
2. Installeer de [Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/) met de SDK Manager en
   download daar het device **fēnix 7X / tactix 7 / quatix 7X Solar** (`fenix7x`).
3. Maak een developer key: in VS Code `Ctrl+Shift+P` > **Monkey C: Generate a Developer Key**.
4. Open deze map (`OpenMeteoWeather`) in VS Code.
5. Testen in de simulator: `F5` of **Monkey C: Run**. Kies in de simulator via *Settings > Set Position*
   een locatie, anders wacht de app op GPS.
6. Op je horloge zetten: **Monkey C: Build for Device**, kies `fenix7x`. Sluit het horloge met USB aan
   en kopieer het `.prg`-bestand uit `bin/` naar `GARMIN/APPS/` op het horloge. Ontkoppel het horloge
   en je vindt de app in het app-menu. Voeg hem toe aan je glances voor een snel overzicht.

Andere horloges toevoegen? Voeg in `manifest.xml` een extra `<iq:product id="..."/>` toe (bijv.
`fenix7`, `fenix7s`, `fenix7xpro`, `epix2`). De layout schaalt mee met de schermgrootte.

## Projectstructuur

```
manifest.xml               app-definitie, device, permissies (Communications, Positioning)
source/WeatherApp.mc       entry point, start model/view/glance
source/WeatherModel.mc     GPS, Open-Meteo request, parsen en cachen
source/WeatherView.mc      de drie pagina's
source/WeatherDelegate.mc  knoppen
source/WeatherGlanceView.mc glance
source/WeatherIcons.mc     vector-weericonen en windpijl
source/WeatherCodes.mc     WMO-weercodes naar tekst
resources*/                teksten (EN/NL), instellingen, icoon
```

Weerdata: [Open-Meteo](https://open-meteo.com/) (CC BY 4.0), gratis voor niet-commercieel gebruik.
