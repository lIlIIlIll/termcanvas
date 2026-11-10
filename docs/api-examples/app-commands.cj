package cjtui_api_example

import core.*
import std.collection.*

main(): Int64 {
    let commands = ArrayList<Command>()
    let update = UpdateResult.withCommand(Command.Batch([Command.Message("ready"), Command.Quit]))
    if (!App.applyUpdateResult(update, commands) || commands.size != 2) { throw IllegalStateException("command batch failed") }
    match (commands[0]) {
        case Command.Message(text) => if (text != "ready") { throw IllegalStateException("message failed") }
        case _ => throw IllegalStateException("unexpected command")
    }
    return 0
}
