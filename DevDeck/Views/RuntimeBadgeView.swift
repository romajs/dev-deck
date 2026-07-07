import SwiftUI

struct RuntimeBadgeView: View {
    let runtime: RuntimeKind

    var body: some View {
        Image(systemName: symbolName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .frame(width: 16, height: 16)
            .help(runtime.displayName)
    }

    private var symbolName: String {
        switch runtime {
        case .node:
            "hexagon.fill"
        case .deno:
            "circle.dotted"
        case .bun:
            "shippingbox.fill"
        case .python:
            "curlybraces"
        case .ruby:
            "diamond.fill"
        case .java:
            "cup.and.saucer.fill"
        case .go:
            "arrowshape.right.circle.fill"
        case .rust:
            "gearshape.fill"
        case .php:
            "server.rack"
        case .dotnet:
            "dot.circle.fill"
        case .elixir:
            "drop.fill"
        case .other:
            "circle.fill"
        }
    }

    private var color: Color {
        switch runtime {
        case .node:
            .green
        case .deno:
            .primary
        case .bun:
            .brown
        case .python:
            .blue
        case .ruby:
            .red
        case .java:
            .orange
        case .go:
            .cyan
        case .rust:
            .gray
        case .php:
            .indigo
        case .dotnet:
            .purple
        case .elixir:
            .pink
        case .other:
            .secondary
        }
    }
}
