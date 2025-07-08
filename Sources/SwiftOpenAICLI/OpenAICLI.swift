import ArgumentParser
import Foundation

@main
struct OpenAICLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swiftopenai",
        abstract: "A command-line interface for OpenAI API",
        discussion: """
            Note: Debug output is controlled at compile time.
            - For debug output: Build with `swift build` (debug mode)
            - For production: Build with `swift build -c release`
            """,
        version: "1.1.0",
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