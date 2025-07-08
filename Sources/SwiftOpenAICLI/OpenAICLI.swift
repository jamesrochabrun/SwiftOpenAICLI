import ArgumentParser
import Foundation

@main
struct OpenAICLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swiftopenai",
        abstract: "A command-line interface for OpenAI API",
        version: "1.0.0",
        subcommands: [
            ChatCommand.self,
            ImageCommand.self,
            ModelsCommand.self,
            CompleteCommand.self,
            EmbedCommand.self,
            ConfigCommand.self
        ],
        defaultSubcommand: ChatCommand.self
    )
}