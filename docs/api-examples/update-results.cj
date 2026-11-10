package cjtui_api_example

import core.*
import std.time.*

main(): Int64 {
    let timer = TimerSpec("refresh", Duration.millisecond * 50, mode: TimerMode.Repeating,
        missPolicy: FrameMissPolicy.Drop)
    if (timer.id != "refresh" || timer.every != Duration.millisecond * 50) {
        throw IllegalStateException("timer configuration failed")
    }
    match ((timer.mode, timer.missPolicy)) {
        case (TimerMode.Repeating, FrameMissPolicy.Drop) => ()
        case _ => throw IllegalStateException("timer mode failed")
    }
    let changed = UpdateResult.dirty(Rect(0, 0, 2, 1)).withDirty(Rect(4, 0, 2, 1))
    if (!changed.renderRequested || changed.dirtyRects.isNone() || UpdateResult.unchanged().renderRequested ||
        !UpdateResult.next().renderRequested) { throw IllegalStateException("redraw request failed") }
    let command = Command.Message("refresh")
    let handled = HandleResult.consumed(command: command)
    let converted = handled.toUpdateResult()
    if (!handled.handled || HandleResult.ignored().handled || !converted.renderRequested) {
        throw IllegalStateException("event result failed")
    }
    match ((converted.flow, converted.command, UpdateResult.exit().flow, HandleResult.exit().flow,
            HandleResult.withCommand(command).command, UpdateResult.withCommand(command).command)) {
        case (ControlFlow.Continue, Command.Message(_), ControlFlow.Exit, ControlFlow.Exit,
              Command.Message(_), Command.Message(_)) => ()
        case _ => throw IllegalStateException("event command failed")
    }
    return 0
}
