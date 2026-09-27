// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// A one-time note for the launch after update, separate from release notes.
struct UpdateSupportIntroView: View {
    var onFinish: () -> Void

    @ObservedObject private var l10n = L10n.shared
    @Environment(\.openURL) private var openURL
    @State private var step: SupportUpdateIntroStep
    @State private var isMovingForward = true

    init(initialStep: SupportUpdateIntroStep = .support,
         onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
        _step = State(initialValue: initialStep)
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                switch step {
                case .support:
                    supportContent
                        .transition(pageTransition)
                case .social:
                    socialContent
                        .transition(pageTransition)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 34)
            .clipped()

            Divider()

            footer
        }
        .frame(width: 560, height: 500)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var pageTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: isMovingForward ? .trailing : .leading)
                .combined(with: .opacity),
            removal: .move(edge: isMovingForward ? .leading : .trailing)
                .combined(with: .opacity)
        )
    }

    private func move(to destination: SupportUpdateIntroStep, forward: Bool) {
        isMovingForward = forward
        withAnimation(.easeInOut(duration: 0.3)) {
            step = destination
        }
    }

    private var socialContent: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(Color.black)
                    .frame(width: 74, height: 74)
                    .overlay(
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
                XLogoShape()
                    .fill(Color.white, style: FillStyle(eoFill: true))
                    .frame(width: 36, height: 36)
            }

            Text(l10n.s.communityIntroTitle)
                .font(.system(size: 22, weight: .bold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(l10n.s.communityIntroMessage)
                .font(.system(size: 13.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 440)

            Button {
                openURL(AppInfo.socialURL)
            } label: {
                HStack(spacing: 8) {
                    XLogoShape()
                        .fill(Color.white, style: FillStyle(eoFill: true))
                        .frame(width: 13, height: 13)
                    Text(l10n.s.communityIntroFollowButton)
                }
            }
            .buttonStyle(XFollowButtonStyle())
            .padding(.top, 4)

            Text(AppInfo.socialURL.absoluteString
                .replacingOccurrences(of: "https://", with: ""))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, 2)
        }
    }

    private var supportContent: some View {
        UpdateSupportContent()
    }

    private var footer: some View {
        ZStack {
            HStack {
                if let previous = step.previous {
                    Button(l10n.s.obBack) {
                        move(to: previous, forward: false)
                    }
                }
                Spacer()
                if let next = step.next {
                    Button(l10n.s.obContinue) {
                        move(to: next, forward: true)
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else {
                    Button(l10n.s.supportIntroDoneButton) {
                        onFinish()
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }

            HStack(spacing: 6) {
                ForEach(SupportUpdateIntroStep.allCases, id: \.self) { candidate in
                    Circle()
                        .fill(candidate == step
                              ? Color.accentColor
                              : Color.secondary.opacity(0.24))
                        .frame(width: 6, height: 6)
                }
            }
            .accessibilityHidden(true)
        }
        .padding(16)
    }
}

private struct UpdateSupportContent: View {
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 13) {
            ZStack {
                Circle()
                    .fill(Theme.spaceGradient)
                    .frame(width: 74, height: 74)
                Image(systemName: "heart.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Text(l10n.s.supportIntroTitle)
                .font(.system(size: 22, weight: .bold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(l10n.s.supportIntroMessage)
                .font(.system(size: 13.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 440)

            Button {
                openURL(AppInfo.coffeeURL)
            } label: {
                Label(l10n.s.supportIntroCoffeeButton,
                      systemImage: "cup.and.saucer.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Text(l10n.s.supportIntroStarMessage)
                .font(.system(size: 13.5, weight: .medium))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 440)
                .padding(.top, 2)

            Button {
                openURL(AppInfo.repositoryURL)
            } label: {
                Label(l10n.s.supportIntroStarButton, systemImage: "star.fill")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Text(l10n.s.donateThanks)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}

/// The X (Twitter) logo as a vector path in a 24x24 design box, scaled to the
/// given rect. Fill with `FillStyle(eoFill: true)` so the inner slash cuts out.
struct XLogoShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24
        let originX = rect.midX - 12 * scale
        let originY = rect.midY - 12 * scale
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: originX + x * scale, y: originY + y * scale)
        }
        var path = Path()
        path.move(to: point(18.244, 2.25))
        path.addLine(to: point(21.552, 2.25))
        path.addLine(to: point(14.325, 10.51))
        path.addLine(to: point(22.827, 21.75))
        path.addLine(to: point(16.17, 21.75))
        path.addLine(to: point(10.956, 14.933))
        path.addLine(to: point(4.99, 21.75))
        path.addLine(to: point(1.68, 21.75))
        path.addLine(to: point(9.41, 12.915))
        path.addLine(to: point(1.254, 2.25))
        path.addLine(to: point(8.08, 2.25))
        path.addLine(to: point(12.793, 8.481))
        path.closeSubpath()
        path.move(to: point(17.083, 19.77))
        path.addLine(to: point(18.916, 19.77))
        path.addLine(to: point(7.084, 4.126))
        path.addLine(to: point(5.117, 4.126))
        path.closeSubpath()
        return path
    }
}

/// X-branded call to action: white label on a black capsule, readable in both
/// appearances thanks to the faint outline.
private struct XFollowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13.5, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 9)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.black)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.75 : 1)
            .contentShape(Capsule(style: .continuous))
    }
}
