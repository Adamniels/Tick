# Projektbrief: Tick, en egen tidtagare för macOS

## Bakgrund

Jag använder Toggl i dag men utnyttjar bara en liten del av det, och det som är viktigast för mig saknas: **påminnelser som faktiskt syns**. Toggls notiser missar jag hela tiden. Jag vill därför bygga en egen, mycket enklare tidtagare som bara gör det jag behöver och som gör det riktigt bra.

Appen är bara för mig. Den körs på mina Macar och synkas mellan dem via iCloud. Den ska inte släppas i App Store.

## Projektet som det ser ut nu

Milstolpe 0 till 7 är klara och appen är installerad (notariserad, CloudKit produktion). Framsteg, beslut (D1 och framåt) och det som återstår finns i `PLAN.md`. Vid konflikt mellan den här briefen och koden eller `PLAN.md` gäller koden och besluten.

* Xcode projekt: `Tick` med app target `Tick` och testtarget `TickTests` (Swift Testing). Delat schema `Tick`.
* Bundle ID: `com.adamniels.Tick`
* CloudKit container: `iCloud.com.adamniels.Tick`
* Signing & Capabilities: automatisk signering, App Sandbox (Outgoing Connections, användarvalda filer läs och skriv), iCloud med CloudKit, Push Notifications, Hardened Runtime (D37).
* `Application is agent (UIElement) = YES` i Info.
* Swift 6 language mode, MainActor som standardisolering (D2, D14).
* Bygg: `xcodebuild -scheme Tick -destination 'platform=macOS' build`
* Testa: `xcodebuild -scheme Tick -destination 'platform=macOS' test`

## Stack och plattform

* **Plattform:** endast macOS (minst macOS 26, se beslut D1 i PLAN.md). Ingen iOS, ingen webb.
* **Språk och UI:** Swift och SwiftUI.
* **Lagring:** SwiftData.
* **Synk:** CloudKit via SwiftData (privat databas i mitt iCloud). Jag har redan Apple Developer Program.
* **Grafer:** Swift Charts.
* **Beroenden:** helst inga externa paket. Undantag som är okej: `KeyboardShortcuts` (sindresorhus) för globala kortkommandon.
* **Distribution:** Archive i Xcode, sedan Distribute App → Direct Distribution (Developer ID och notarisering), exportera och lägg i Program. Samma notariserade app kopieras till mina andra Macar. Startar automatiskt vid inloggning via `SMAppService.mainApp`. Steg för steg i `PLAN.md`, milstolpe 6.

## Appens form

* En **menyradsapp** utan ikon i Dock (`LSUIElement = YES`). Byggd med `NSStatusItem` och `NSPopover` i AppKit, inte `MenuBarExtra`, eftersom etiketten måste uppdateras varje sekund och panelen inte får flytta sig medan den är öppen (D16, D24).
* Menyraden visar alltid status: projektfärg, projektnamn och förfluten tid, till exempel `● 0:42:13 Operation Rollout`. När ingen timer går visas bara en ikon.
* Ett klick på menyraden öppnar en kompakt panel för att starta och stoppa, välja projekt och taggar, och se dagens poster.
* Ett **huvudfönster** (öppnas från panelen) med lista över poster, manuella poster, projekt och taggar, statistik och inställningar.

## Funktioner

### 1. Timer (start och stopp)

* Starta en timer med valfri beskrivning, valfritt projekt och noll eller flera taggar.
* **Bara en timer kan gå åt gången.** Om jag startar en ny stoppas den gamla automatiskt.
* Stoppa från menyraden eller med ett globalt kortkommando.
* "Fortsätt" på en tidigare post startar en ny timer med samma beskrivning, projekt och taggar.
* En timer som går sparas som en `TimeEntry` med `start` satt och `end == nil`. Förfluten tid räknas alltid fram från `start`, aldrig med en räknare som sparas.

### 2. Manuella poster

* Lägg till en post i efterhand med start, slut, beskrivning, projekt och taggar.
* Redigera och ta bort befintliga poster.
* Validering: slut måste vara efter start. Överlappande poster är tillåtna men markeras visuellt.

### 3. Projekt och taggar med färger

* Skapa, byta namn på, färglägga och arkivera projekt och taggar.
* Färg väljs med en färgväljare och sparas som hexsträng.
* Arkiverade projekt syns inte i väljaren men ligger kvar i historik och statistik.

### 4. Pomodoro

* Valfritt läge som körs ovanpå den vanliga timern.
* Standard: 25 min arbete, 5 min kort paus, 15 min lång paus efter var fjärde arbetspass. Alla tider går att ändra i inställningarna.
* När ett pass eller en paus tar slut visas **popupen** (se nästa punkt).
* Menyraden visar vilken fas som pågår och hur mycket tid som är kvar, till exempel `🍅 18:42`.
* Pausen räknas inte som arbetstid. Tidsposten pausas (stoppas och fortsätts med ny post) när pausen börjar, om inte jag väljer något annat i inställningarna.

### 5. Den tydliga popupen (viktigaste funktionen)

Det här är hela anledningen till att jag bygger appen. Den får inte gå att missa.

* **Inte** en vanlig notis i Notification Center. Ett eget fönster.
* Implementeras som ett `NSPanel` med:
  * `level = .screenSaver` (eller högre vid behov) så att det ligger över allt.
  * `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]` så att det syns på alla Spaces och ovanpå appar i helskärm.
  * Ett fönster per skärm (`NSScreen.screens`) så att det syns oavsett vilken skärm jag tittar på.
* Tonar ner hela skärmen bakom (halvgenomskinlig mörk bakgrund) med ett tydligt kort i mitten.
* Spelar ett ljud (valbart i inställningarna).
* Aktiverar appen (`NSApp.activate`) så att knapparna går att klicka direkt.
* **Försvinner inte av sig själv** och inte av misstag (Esc eller klick utanför stänger inte). Jag måste välja en knapp.
* Knappar beroende på situation, till exempel:
  * Efter arbetspass: "Starta paus", "Kör 5 min till", "Avsluta pomodoro".
  * Efter paus: "Starta nästa pass", "Förläng pausen 5 min", "Avsluta".
  * Tomgångspåminnelse: snabbstart av senaste projekten, "Starta ny timer", "Påminn om 15 min".
* Utseende (nedtoning, ljud, storlek) ställs in i inställningarna. Det ska finnas en knapp "Testa popup".

### 6. Påminnelser

* **Tomgångspåminnelse:** om ingen timer har gått på X minuter under mina arbetstider visas popupen och frågar vad jag jobbar med. X och arbetstider (dagar och klockslag) ställs in i inställningarna.
* **Glömd timer:** om en timer har gått längre än Y timmar (till exempel 3 h) visas popupen och frågar om jag fortfarande jobbar, med möjlighet att stoppa den vid en vald tidpunkt i efterhand.
* **Datorn har varit vilande eller låst:** när jag kommer tillbaka och en timer har gått hela tiden, fråga om tiden i vila ska räknas eller tas bort.

### 7. Statistik

* Välj period: idag, denna vecka, denna månad eller eget intervall.
* Total tid per projekt (stapeldiagram eller munkdiagram i projektfärger).
* Total tid per tagg.
* Tid per dag i perioden (staplade staplar per projekt).
* Antal avklarade pomodoros per dag.
* Enkel siffra högst upp: total tid i perioden och jämförelse med förra perioden.

### 8. Kalendervy (byggd i milstolpe 7)

* Dagvy likt Toggl där poster ritas som block på en tidslinje.
* Dra för att skapa en post, dra i kanterna för att ändra tid, dra blocket för att flytta det (D34).

### 9. Export (byggd i milstolpe 7)

* All data som versionerad JSON (för att flytta till en ny app eller databas) och poster som CSV, under Inställningar → Data (D35).

## Datamodell

Koden i `Tick/Models/` är den gällande versionen. Modellerna deklareras dessutom `nonisolated` (D14).

Regler som krävs för att SwiftData ska kunna synka med CloudKit:

* Alla egenskaper måste ha standardvärde eller vara optional.
* Ingen `@Attribute(.unique)`.
* Alla relationer måste vara optional och ha en inverse.

```swift
@Model final class Project {
    var id: UUID = UUID()
    var name: String = ""
    var colorHex: String = "#8E8E93"
    var isArchived: Bool = false
    var createdAt: Date = Date()
    @Relationship(deleteRule: .nullify, inverse: \TimeEntry.project)
    var entries: [TimeEntry]? = []
}

@Model final class Tag {
    var id: UUID = UUID()
    var name: String = ""
    var colorHex: String = "#8E8E93"
    var isArchived: Bool = false
    @Relationship(deleteRule: .nullify, inverse: \TimeEntry.tags)
    var entries: [TimeEntry]? = []
}

@Model final class TimeEntry {
    var id: UUID = UUID()
    var entryDescription: String = ""
    var start: Date = Date()
    var end: Date? = nil            // nil betyder att timern går
    var isPomodoro: Bool = false
    var project: Project? = nil
    var tags: [Tag]? = []
    var updatedAt: Date = Date()
}

@Model final class PomodoroSession {
    var id: UUID = UUID()
    var runID: UUID = UUID()        // grupperar ett pomodoropass (D21)
    var phase: String = "work"      // work, shortBreak, longBreak
    var start: Date = Date()
    var plannedEnd: Date = Date()
    var endedAt: Date? = nil        // nil betyder aktiv fas (D21)
    var completed: Bool = false
}
```

**Lokala inställningar** (synkas inte, sparas med `@AppStorage` eller `UserDefaults`): pomodorotider, arbetstider, tröskel för tomgång och glömd timer, ljud och utseende för popupen, kortkommandon.

## Synk och CloudKit

* `ModelConfiguration(cloudKitDatabase: .private("iCloud.com.adamniels.Tick"))`.
* **Viktigt:** en app exporterad med Direct Distribution använder CloudKits produktionsmiljö; byggen från Xcode använder utvecklingsmiljön. Efter varje ändring i modellen måste schemat driftsättas via "Deploy Schema Changes" i CloudKit Console, och nya posttyper finns först i utvecklingsmiljön när en post av den typen har synkats dit (många till många relationer syns som `CDMR`).
* Varje miljö har en egen lokal databasfil, vald efter appens signerade miljö (D36): `Tick-Production.store` för produktion, `Tick.store` för utveckling. Annars skulle testdata laddas upp till produktion.
* Synken kan ta några sekunder upp till en minut. Appen ska hantera att två poster med `end == nil` dyker upp efter synk (till exempel om jag startat på två Macar): behåll den senast startade och stoppa den andra vid den andras starttid.
* Popupen och pomodorologiken räknas fram lokalt på varje Mac från synkad data (`start`, `plannedEnd`). Popupen skickas aldrig via databasen.

## Utanför scope

* iOS, iPadOS, webb eller andra plattformar.
* Team, delning, fakturering, timpris och kunder.
* Integrationer (kalendrar, Jira och liknande).
* Egen server eller eget konto.

Möjligt senare (milstolpe 8): import av historik från Toggl via CSV, och återställning från en Tick export.

## Struktur

```
Tick/
  App/            TickApp, AppDelegate (sammankopplar allt, sekundloopen), StatusItemController,
                  MainWindowController, Persistence (ModelContainer per CloudKit miljö)
  Models/         Project, Tag, TimeEntry, PomodoroSession, ColoredLabel
  Services/       TrackingService (start, stopp, fortsätt), TimerService (poster), PomodoroService,
                  PomodoroCycle, ReminderService, Reminders, OverlayController, Statistics,
                  CalendarLayout, EntryEditing, DataExport, ErrorReporter
  Views/
    MenuBar/      menyradspanelen
    Timer/        start, stopp och pomodoro, delas av panelen och huvudfönstrets toppfält
    Main/         huvudfönstret: poster, redigering, projekt och taggar
    Calendar/     dagvyn
    Stats/        statistik med Swift Charts
    Overlay/      popupens SwiftUI vy
    Settings/     en fil per flik
  Utilities/      AppSettings, Color+Hex, DurationFormat, LaunchAtLogin, Log, Shortcuts
TickTests/        enhetstester för all logik (Swift Testing)
scripts/          make-app-icon.swift
```

Logiken ligger i rena funktioner och tjänster med injicerbar klocka, så att den går att testa. Vyerna är tunna.

## Milstolpar

Status och detaljer finns i `PLAN.md`.

0. **Städning:** gitignore, Swift 6, testtarget. ✅
1. **Grund:** datamodell, CloudKit kopplat i koden, menyradsapp utan Dock ikon, starta och stoppa timer, projekt och taggar med färger. ✅
2. **Popupen:** `OverlayController` med fönster per skärm, testknapp, pomodoro med alla faser. ✅
3. **Påminnelser:** tomgång, glömd timer, vila och låst skärm. ✅
4. **Huvudfönster:** lista grupperad per dag, manuella poster, redigera och ta bort. ✅
5. **Statistik.** ✅
6. **Finputs och installation:** globala kortkommandon, inloggningsobjekt, inställningar, ikon, notariserad installation. ✅ (testet med två Macar klart 2026-10-03)
7. **Kalendervy och export.** ✅
8. **(Senare)** Import från Toggl och återställning från en Tick export.

Varje milstolpe ska ge en app som går att köra och använda.

## Instruktioner till den som bygger

* Planen och framstegen finns i `PLAN.md`. Läs den först, bocka av uppgifter och logga beslut där.
* Jobba en milstolpe i taget och stäm av med mig innan nästa påbörjas.
* Håll koden enkel och läsbar. Hellre få filer med tydligt ansvar än abstraktioner i förväg.
* Följ CloudKit reglerna ovan för varje ändring i modellen, och påminn mig om att driftsätta schemat.
* Fråga om något i den här briefen är oklart eller verkar fel i stället för att gissa.

## Öppna frågor

Inga just nu. Frågorna som fanns här är besvarade i `PLAN.md`: pomodoro slås på per timer (D8a), tidsposten stoppas under pauser men det går att ändra i inställningarna (D8b), och panelen visar dagens poster med en dagssumma (D8c). Nya frågor samlas under "Open questions" i `PLAN.md`.
