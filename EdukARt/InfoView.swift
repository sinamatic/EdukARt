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

                    InfoTextSection(
                        title: "Von der Bachelorarbeit zum Forschungsprojekt",
                        primaryText: "EdukARt ist als Bachelorarbeit von Sina Steinmüller im Studiengang Media Engineering entstanden und wird nun im Master of Applied Research weitergeführt. Für die Entwicklung und Erprobung des ersten Prototyps wurde Eduard von EduArt Robotik verwendet."
                    )

                    InfoTextSection(
                        title: "Ein Projekt zum Mitgestalten",
                        primaryText: "Die App befindet sich noch in der Testphase. Aktuell wird untersucht, welche Spielideen, Funktionen und Einsatzbereiche besonders interessant sind – ob auf Messen, in Bildungsprojekten oder beim Spielen mit dem eigenen Roboter. Deine Erfahrungen und Ideen helfen dabei, die weitere Richtung von EdukARt mitzubestimmen."
                    )

                    InfoTextSection(
                        title: "Ausprobieren und Feedback geben",
                        primaryText: "Übernimm die Steuerung und erlebe, wie ein echter Roboter auf virtuelle Spielelemente reagiert! Wenn du anschließend die Umfrage ausfüllst, unterstützt du die weitere Forschung und Entwicklung. Was macht Spaß? Was fehlt? Was würdest du dir wünschen? Auch Anregungen direkt am Stand sind willkommen.",
                        linkTitle: "Zur Umfrage",
                        linkURLString: "https://www.umfrageonline.com/c/btxxap4r"
                    )

                    InfoTextSection(
                        title: "Dein eigener Roboter in EdukARt",
                        primaryText: "Als nächster Schritt ist geplant, dass du eigene Roboter für EdukARt bauen oder bereits vorhandene Modelle einbinden kannst. So soll aus dem Spiel auch ein Anlass werden, gemeinsam zu tüfteln und eigene Ideen umzusetzen.",
                        secondaryText: "Die technische Grundlage bildet die EdukARt-ROS-2-Brücke: Ein Python-Skript auf dem Roboter nimmt Befehle der App über WLAN entgegen und leitet sie an dessen ROS-2-Schnittstellen weiter. Dieser Ansatz soll grundsätzlich die Anbindung unterschiedlicher ROS-2-kompatibler Roboter ermöglichen. Dafür müssen die jeweiligen Steuerungsschnittstellen passend konfiguriert werden; bisher wurde die Anbindung mit Eduard erprobt."
                    )

                    InfoContactSection()

                    InfoPrivacyLink()
                }
                .padding(24)
            }
        }
        .navigationTitle("Infos")
        .navigationBarTitleDisplayMode(.inline)
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
