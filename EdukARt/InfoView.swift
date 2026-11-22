//
//  InfoView.swift
//  EdukARt
//
//  Created by Sina Steinmüller.
//

import SwiftUI

struct InfoView: View {
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    InfoHeader()

                    InfoTextSection(
                        title: "EdukARt – echte Roboter, virtuelle Abenteuer",
                        primaryText: "Steuere einen echten Roboter durch eine Rennstrecke mit virtuellen Hindernissen und Items: EdukARt verbindet Robotik mit Augmented Reality. Auf dem iPhone verschmelzen die reale Umgebung und digitale Spielelemente – virtuelle Ereignisse beeinflussen dabei die Bewegung und Beleuchtung des echten Roboters.",
                        secondaryText: "Die Idee dahinter: Spaß am Spielen mit Bewegung verbinden, Neugier auf Technik wecken und dazu motivieren, eigene Roboter zu bauen, zu programmieren und weiterzuentwickeln."
                    )

                    InfoGameInstructions()

                    InfoGameItems()

                    InfoTextSection(
                        title: "Eigenen Roboter verwenden",
                        primaryText: "Im Menü „Robot Remote“ gibt es eine rudimentäre Möglichkeit, eigene Roboter hinzuzufügen. Dort kannst du die ROS-Informationen und Steuerungsschnittstellen an deinen Roboter anpassen.",
                        secondaryText: "Diese Funktion wurde noch nicht ausgiebig getestet. Bitte gib uns Feedback zu deinen Erfahrungen, Problemen und Verbesserungsvorschlägen."
                    )

                    InfoTextSection(
                        title: "Von der Bachelorarbeit zum Forschungsprojekt",
                        primaryText: "EdukARt ist als Bachelorarbeit von Sina Steinmüller im Studiengang Media Engineering entstanden und wird nun im Master of Applied Research weitergeführt. Für die Entwicklung und Erprobung des ersten Prototyps wurde Eduard von EduArt Robotik verwendet."
                    )

                    InfoTextSection(
                        title: "Ein Projekt zum Mitgestalten",
                        primaryText: "Die App befindet sich noch in der Testphase. Aktuell wird untersucht, welche Spielideen, Funktionen und Einsatzbereiche besonders interessant sind – ob auf Messen, in Bildungsprojekten oder beim Spielen mit dem eigenen Roboter. Deine Erfahrungen und Ideen helfen dabei, die weitere Richtung von EdukARt mitzubestimmen."
                    )

                    InfoContactSection()

                    InfoPrivacyLink()

                    InfoTextSection(
                        title: "Feedback geben",
                        primaryText: "Was macht Spaß? Was fehlt? Teile deine Erfahrungen mit EdukARt und hilf dabei, die App weiterzuentwickeln.",
                        linkTitle: "Zur Feedback-Umfrage",
                        linkURLString: "https://www.umfrageonline.com/c/btxxap4r"
                    )
                }
                .padding(24)
            }
        }
        .navigationTitle("Infos")
        .navigationBarTitleDisplayMode(.inline)
    }
}


private struct InfoGameInstructions: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Spielanleitung")
                .font(.title2.bold())
                .foregroundStyle(Color("BrandGreen"))

            InfoTextSection(
                title: "1. Allgemeines",
                primaryText: "Drucke die AprilTags über das Tutorial aus – einseitig und in tatsächlicher Größe mit 100 % Skalierung. Versionen für den 3D-Druck gibt es bald auf sinamatic.de/edukart.",
                secondaryText: "Verbinde dein iPhone per WLAN mit dem Roboter. Über den Knopf rechts oben kannst du ihn aktivieren oder deaktivieren. Bei Verbindungsproblemen verwende den roten Not-Aus-Knopf am Roboter.",
                linkTitle: "Zu sinamatic.de/edukart",
                linkURLString: "https://www.sinamatic.de/edukart/"
            )

            InfoTextSection(
                title: "2. Strecken erstellen",
                primaryText: "Verteile die AprilTags im Raum mit weniger als 3 m Abstand zueinander. Öffne „Courses“ und „Create Course“ und scanne die Tags. Der zuerst gescannte Tag wird zum Referenzpunkt für die gesamte Strecke.",
                secondaryText: "Achte auf die Ausrichtung des Referenz-Tags: Die blaue Ecke muss beim Scannen unten rechts liegen. Andernfalls ist die Orientierung der Strecke falsch. Merke dir den Referenz-Tag für den Spielstart."
            )

            InfoTextSection(
                title: "3. Spiel starten",
                primaryText: "Wähle unter „Start Game“ eine Strecke aus. Scanne ihren Referenz-Tag erneut, um die AR-Strecke im Raum zu platzieren und das Spiel zu starten."
            )
        }
    }
}

private struct InfoGameItems: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Items und Hindernisse")
                .font(.title2.bold())
                .foregroundStyle(Color("BrandGreen"))

            InfoGameItemRow(icon: "🪙", title: "Münze", effect: "Kurzzeitiger Geschwindigkeitsschub. Jede fehlende Münze addiert 5 Sekunden zur Endzeit.")
            InfoGameItemRow(icon: "🎁", title: "Itembox", effect: "Einsammeln zieht 20 Sekunden von der Endzeit ab.")
            InfoGameItemRow(icon: "💧", title: "Wasser", effect: "Bewege dich mit vielen kurzen Joystick-Inputs durch das Wasser. Lass den Joystick zwischen den Schwimmzügen in die Mitte zurückkehren.")
            InfoGameItemRow(icon: "🌳", title: "Baum", effect: "Ein Hindernis erscheint. Ein Zusammenstoß verursacht Schaden und verringert die Geschwindigkeit.")
            InfoGameItemRow(icon: "🪨", title: "Stein", effect: "Blockiert den Weg. Ein Zusammenstoß verursacht Schaden und verringert die Geschwindigkeit.")
            InfoGameItemRow(icon: "🛢️", title: "Öl", effect: "Eduard dreht sich vorübergehend automatisch. Das Fass blockiert den Weg.")
            InfoGameItemRow(icon: "💩", title: "Shit", effect: "Eduard fährt vorübergehend automatisch im Zickzack und hinterlässt eine Schmutzspur.")
            InfoGameItemRow(icon: "🥚", title: "Ei", effect: "Einsammeln und zum Nest transportieren.")
            InfoGameItemRow(icon: "🪺", title: "Cup / Nest", effect: "Liefere gesammelte Eier ab, um Schaden zu reparieren und die normale Geschwindigkeit wiederherzustellen.")
        }
    }
}

private struct InfoGameItemRow: View {
    let icon: String
    let title: LocalizedStringResource
    let effect: LocalizedStringResource

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(verbatim: icon)
                .font(.title2)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(effect)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct InfoHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EdukARt")
                .font(.largeTitle.bold())
                .foregroundStyle(Color("BrandGreen"))

            Text("Echte Roboter. Virtuelle Abenteuer.")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            if let websiteURL = URL(string: "https://www.sinamatic.de/edukart/") {
                Link(destination: websiteURL) {
                    Text(verbatim: "www.sinamatic.de/edukart")
                }
                .font(.headline)
                .foregroundStyle(Color("BrandGreen"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct InfoTextSection: View {
    let title: LocalizedStringResource
    let primaryText: LocalizedStringResource
    var secondaryText: LocalizedStringResource? = nil
    var linkTitle: LocalizedStringResource? = nil
    var linkURLString: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(Color("BrandGreen"))

            Text(primaryText)
                .font(.body)
                .foregroundStyle(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)

            if let secondaryText {
                Text(secondaryText)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let linkTitle,
               let linkURLString,
               let linkURL = URL(string: linkURLString) {
                Link(linkTitle, destination: linkURL)
                    .font(.headline)
                    .foregroundStyle(Color("BrandGreen"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct InfoPrivacyLink: View {
    var body: some View {
        VStack(spacing: 8) {
            if let privacyPolicyURL = URL(string: "https://www.sinamatic.de/edukart/datenschutz/") {
                Link("Datenschutzerklärung", destination: privacyPolicyURL)
            }

            if let websiteURL = URL(string: "https://www.sinamatic.de/edukart/") {
                Link(destination: websiteURL) {
                    Text(verbatim: "www.sinamatic.de/edukart")
                }
            }
        }
        .font(.footnote)
        .foregroundStyle(Color("BrandGreen"))
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct InfoContactSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Kontakt, Kooperation und Sponsoring")
                .font(.title2.bold())
                .foregroundStyle(Color("BrandGreen"))

            Text("Du hast Feedback, möchtest deinen Roboter einbinden oder EdukARt durch eine Kooperation oder Sponsoring unterstützen? Ich freue mich über deine Nachricht!")
                .font(.body)
                .foregroundStyle(.white.opacity(0.9))

            Text("Sina Steinmüller")
                .font(.headline)
                .foregroundStyle(.white)

            if let emailURL = URL(string: "mailto:hello@sinamatic.de") {
                Link("hello@sinamatic.de", destination: emailURL)
                    .font(.headline)
                    .foregroundStyle(Color("BrandGreen"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
    }
}

#Preview {
    NavigationStack {
        InfoView()
    }
}
