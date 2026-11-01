import SwiftUI

enum ConsumentaTutorialStep: Equatable {
    case welcome
    case wifi
    case robotRemote
    case emergencyStop
    case courses
    case courseSelection
    case mapLocalization
    case arStart
    case arControls
    case gameGoal
}

struct ConsumentaTutorialView: View {
    let step: ConsumentaTutorialStep
    let canAdvance: Bool
    let onNext: () -> Void
    let onBack: () -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(step == .mapLocalization ? 0.82 : 0.72)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack {
                if step != .mapLocalization {
                    Spacer(minLength: 0)
                }

                ConsumentaTutorialCard(
                    step: step,
                    canAdvance: canAdvance,
                    onNext: onNext,
                    onBack: onBack,
                    onClose: onClose
                )

                if step == .mapLocalization {
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
        }
    }
}

private struct ConsumentaTutorialCard: View {
    let step: ConsumentaTutorialStep
    let canAdvance: Bool
    let onNext: () -> Void
    let onBack: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                Label(title, systemImage: icon)
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(.white.opacity(0.12))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Tutorial schließen")
            }

            if step == .arControls {
                Text("Im AR-Menü links oben findest du diese Funktionen:")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.88))

                ConsumentaTutorialListRow(
                    title: "Sync",
                    message: "Platziert den AR-Eduard einmalig auf dem echten Eduard."
                )
                ConsumentaTutorialListRow(
                    title: "Live Sync",
                    message: "Synchronisiert den AR-Eduard dauerhaft mit dem echten Eduard."
                )
                ConsumentaTutorialListRow(
                    title: "Show Ghost",
                    message: "Blendet die beste gespeicherte Fahrt ein."
                )
            } else if step == .gameGoal {
                Text("Sammle alle Münzen ein und erziele die Bestzeit.")
                    .font(.headline)
                    .foregroundStyle(.white)

                VStack(spacing: 8) {
                    ConsumentaTutorialItemRow(
                        icon: "🪙",
                        title: "Münze",
                        effect: "+5 Sek. je fehlender Münze"
                    )
                    ConsumentaTutorialItemRow(
                        icon: "💧",
                        title: "Wasser",
                        effect: "Viele kurze Joystick-Inputs"
                    )
                    ConsumentaTutorialItemRow(
                        icon: "🌳",
                        title: "Baum",
                        effect: "Hindernis erscheint"
                    )
                    ConsumentaTutorialItemRow(
                        icon: "🪨",
                        title: "Stein",
                        effect: "Hindernis"
                    )
                    ConsumentaTutorialItemRow(
                        icon: "🛢️",
                        title: "Öl",
                        effect: "Eduard dreht sich"
                    )
                    ConsumentaTutorialItemRow(
                        icon: "💩",
                        title: "Shit",
                        effect: "Zickzackfahrt und Schmutzspur"
                    )
                    ConsumentaTutorialItemRow(
                        icon: "🥚",
                        title: "Ei",
                        effect: "Einsammeln und transportieren"
                    )
                    ConsumentaTutorialItemRow(
                        icon: "🪺",
                        title: "Cup",
                        effect: "Gesammelte Eier abliefern"
                    )
                }

                Text("Los geht’s!")
                    .font(.headline.bold())
                    .foregroundStyle(Color("BrandGreen"))
                    .fixedSize(horizontal: false, vertical: true)
            } else if step == .arStart {
                Text("Eduard muss hinter der Startlinie stehen, bevor das Spiel beginnen kann.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.88))

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)

                    Text("Wichtig: Der AprilTag muss während des Spiels immer in der Kameraansicht sichtbar sein. Bleibe daher nah beim Roboter und behalte ihn in der Ansicht. Je näher du dranbleibst, desto besser ist das Spielerlebnis.")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(.yellow.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Text("Sobald das Spiel startet, sind auch die Items aktiv. Ohne echten Roboter kannst du links oben mit „Show Eduard“ den AR-Eduard einblenden und damit spielen.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.88))
            } else {
                Text(message)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if step == .emergencyStop {
                VStack(alignment: .leading, spacing: 8) {
                    ConsumentaTutorialStatusRow(
                        color: .red,
                        message: "Rot: Eduard ist nicht erreichbar."
                    )
                    ConsumentaTutorialStatusRow(
                        color: .yellow,
                        message: "Gelb: Eduard ist verbunden, aber deaktiviert."
                    )
                    ConsumentaTutorialStatusRow(
                        color: .green,
                        message: "Grün: Eduard ist verbunden und aktiviert."
                    )
                }
                .font(.subheadline)

                Text("SICHERHEITSHINWEIS")
                    .font(.headline.bold())
                    .foregroundStyle(.red)

                Text("Fahre niemals in Personen oder reale Hindernisse und stoppe den Roboter immer rechtzeitig. Auf dem Roboter selbst befindet sich für den Notfall ebenfalls ein roter Knopf.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 12) {
                if step != .welcome {
                    Button(action: onBack) {
                        Label("Zurück", systemImage: "chevron.backward")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .background(.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                if canAdvance {
                    Button(action: onNext) {
                        Text(step == .gameGoal ? "Tutorial beenden" : "Weiter")
                            .font(.headline)
                            .frame(
                                maxWidth: .infinity,
                                minHeight: 46,
                                alignment: .center
                            )
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .background(Color("BrandGreen"))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .transaction { transaction in
                transaction.animation = nil
            }
        }
        .padding(20)
        .background(.black.opacity(0.78))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(.white.opacity(0.7), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private var title: LocalizedStringResource {
        switch step {
        case .welcome: "Willkommen bei EdukARt"
        case .wifi: "Mit Eduard verbinden"
        case .robotRemote: "Robot Remote"
        case .emergencyStop: "Not-Aus"
        case .courses: "Courses"
        case .courseSelection: "Wähle eine Strecke"
        case .mapLocalization: "Karte anzeigen"
        case .arStart: "Start des Spiels"
        case .arControls: "AR-Menü"
        case .gameGoal: "Ziel des Spiels"
        }
    }

    private var icon: String {
        switch step {
        case .welcome: "flag.checkered"
        case .wifi: "wifi"
        case .robotRemote: "gamecontroller"
        case .emergencyStop: "power"
        case .courses, .courseSelection: "map"
        case .mapLocalization, .arStart: "camera.viewfinder"
        case .arControls: "cube.transparent"
        case .gameGoal: "trophy.fill"
        }
    }

    private var message: LocalizedStringResource {
        switch step {
        case .welcome:
            "Consumenta Edition – Halle 1, Stand B41 bei EduArt Robotik.\n\nSteuere hier auf der Consumenta mit dieser App unseren Roboter Eduard durch eine AR-Strecke und spiele um die Bestzeit. EdukARt ist ein Prototyp – bitte verzeih, wenn noch nicht alles perfekt funktioniert."
        case .wifi:
            "Verbinde dein iPhone zuerst mit dem WLAN „Eduard_Blue3“. Das Passwort lautet wie das WLAN selbst: „Eduard_Blue3“ – achte dabei auf die Groß- und Kleinschreibung.\n\nWenn du gerade keinen echten Eduard zur Verfügung hast, kannst du im Spiel selbst einen AR-Roboter einblenden."
        case .robotRemote:
            "„Robot Remote“ ist die Fernsteuerung für den Roboter. Hier findest du einen Joystick, kannst die Lichter steuern, die Verbindung prüfen und Bildschirmaufnahmen von der Steuerung des Roboters machen."
        case .emergencyStop:
            "Der Not-Aus oben rechts stoppt Eduard jederzeit sofort. Drücke den Knopf nun einmal. Daneben zeigt dir die Ampel den aktuellen Verbindungsstatus des Roboters an."
        case .courses:
            "Die Erstellung von Strecken ist aktuell deaktiviert. Für Vorschläge melde dich bitte bei uns."
        case .courseSelection:
            "Wähle jetzt eine der vorbereiteten Strecken aus und tippe auf „Start Game“."
        case .mapLocalization:
            "Um die AR-Strecke anzuzeigen, scanne den schwarz-weißen Referenz-AprilTag. Er ist mit rotem Klebeband hervorgehoben. Stelle dich auf die Seite des Pfeils. Der Tag muss nicht das gesamte Rechteck füllen; zeige den Code einfach im Stehen im Fenster an. Falls nichts passiert, gehe etwas näher heran oder weiter weg."
        case .arStart:
            ""
        case .arControls:
            ""
        case .gameGoal:
            ""
        }
    }
}

private struct ConsumentaTutorialItemRow: View {
    let icon: String
    let title: LocalizedStringResource
    let effect: LocalizedStringResource

    var body: some View {
        HStack(spacing: 10) {
            Text(icon)
                .font(.title3)
                .frame(width: 28)

            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(width: 62, alignment: .leading)

            Text(effect)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))

            Spacer(minLength: 0)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct ConsumentaTutorialStatusRow: View {
    let color: Color
    let message: LocalizedStringResource

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "circle.fill")
                .foregroundStyle(color)

            Text(message)
                .foregroundStyle(.white)
        }
    }
}

private struct ConsumentaTutorialListRow: View {
    let title: LocalizedStringResource
    let message: LocalizedStringResource

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color("BrandGreen"))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.78))
            }
        }
    }
}
