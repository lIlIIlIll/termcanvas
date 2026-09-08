package game_demo

import core.*
import std.collection.*
import std.convert.*
import std.fs.*

const FARM_W: Int64 = 32
const FARM_H: Int64 = 18
const FARM_CELL_W: Int64 = 4
const FARM_CELL_H: Int64 = 2
const VIEW_W: Int64 = 184
const VIEW_H: Int64 = 51
const TARGET_FPS: Int64 = 30
const ANIMATION_FRAME_DIVISOR: Int64 = 8
const DAY_START: Int64 = 360
const DAY_END: Int64 = 1320
const DAY_REAL_MILLIS: Int64 = 240000
const DAY_GAME_MINUTES: Int64 = DAY_END - DAY_START
const MAX_ENERGY: Int64 = 100
const TOOL_HOE: Int64 = 0
const TOOL_WATER: Int64 = 1
const TOOL_SEED: Int64 = 2
const TOOL_HARVEST: Int64 = 3
const DIR_UP: Int64 = 0
const DIR_RIGHT: Int64 = 1
const DIR_DOWN: Int64 = 2
const DIR_LEFT: Int64 = 3
const CROP_TURNIP: Int64 = 0
const CROP_POTATO: Int64 = 1
const CROP_BERRY: Int64 = 2
const CROP_COUNT: Int64 = 3
// Save-domain limits keep every crop-price product and balance sum representable.
const MAX_SAVE_COUNT: Int64 = 1000000
const MAX_SAVE_MONEY: Int64 = 1000000000000000
const MAX_SAVE_DAY: Int64 = 1000000000

let FARM_ROWS = [
    "################################",
    "#..............~~~~~...........#",
    "#..............~~~~~...........#",
    "#..HHHH........~~~~~.....S.....#",
    "#..HBHH..................C.....#",
    "#..............................#",
    "#..............................#",
    "#..............................#",
    "#..............................#",
    "#..............................#",
    "#..............................#",
    "#..............................#",
    "#..............................#",
    "#..............................#",
    "#..............................#",
    "#..............................#",
    "#..............................#",
    "################################"
]

struct Options {
    let savePath: String
    let resetSave: Bool
    let headlessSmoke: Bool

    init(savePath: String, resetSave: Bool, headlessSmoke: Bool) {
        this.savePath = savePath
        this.resetSave = resetSave
        this.headlessSmoke = headlessSmoke
    }
}

class Plot {
    let x: Int64
    let y: Int64
    var tilled: Bool = false
    var crop: Int64 = -1
    var growth: Int64 = 0
    var watered: Bool = false

    init(x: Int64, y: Int64) {
        this.x = x
        this.y = y
    }

    func hasCrop(): Bool { crop >= 0 }
}

class FarmGame {
    let metrics = AppMetrics()
    let savePath: String
    let plots = ArrayList<Plot>()
    var day: Int64 = 1
    var minute: Int64 = DAY_START
    var minuteRemainderMillis: Int64 = 0
    var money: Int64 = 120
    var energy: Int64 = MAX_ENERGY
    var playerX: Int64 = 6
    var playerY: Int64 = 6
    var facing: Int64 = DIR_DOWN
    var selectedTool: Int64 = TOOL_HOE
    var selectedCrop: Int64 = CROP_TURNIP
    var seeds = [2, 0, 0]
    var inventory = [0, 0, 0]
    var shipping = [0, 0, 0]
    var status = "new farm: buy seeds, till soil, water daily, ship harvests"
    var lastEarned: Int64 = 0
    var tick: Int64 = 0
    var viewX: Int64 = 0
    var viewY: Int64 = 0
    var saveLoaded: Bool = false
    var saveAllowed: Bool = true

    init(savePath: String, resetSave: Bool) {
        this.savePath = savePath
        buildPlots()
        if (resetSave) {
            save()
        } else {
            try {
                if (exists(Path(savePath))) {
                    saveLoaded = load()
                    if (!saveLoaded) {
                        saveAllowed = false
                        status = "could not load; original save preserved: " + savePath + " (use --reset-save to replace)"
                    }
                } else {
                    status = "fresh save: " + status
                    save()
                }
            } catch (_) {
                saveAllowed = false
                status = "could not inspect save; original path preserved: " + savePath
            }
        }
    }

    func update(event: Event): UpdateResult {
        match (event) {
            case Event.KeyDown(key) =>
                let oldX = playerX
                let oldY = playerY
                let oldTargetX = targetX()
                let oldTargetY = targetY()
                let oldDay = day
                match (key.code) {
                    case KeyCode.CtrlC | KeyCode.Char(r'q') => return UpdateResult.exit()
                    case KeyCode.Left | KeyCode.Char(r'a') =>
                        move(-1, 0, DIR_LEFT)
                        return movementDirty(oldX, oldY, oldTargetX, oldTargetY)
                    case KeyCode.Right | KeyCode.Char(r'd') =>
                        move(1, 0, DIR_RIGHT)
                        return movementDirty(oldX, oldY, oldTargetX, oldTargetY)
                    case KeyCode.Up | KeyCode.Char(r'w') =>
                        move(0, -1, DIR_UP)
                        return movementDirty(oldX, oldY, oldTargetX, oldTargetY)
                    case KeyCode.Down | KeyCode.Char(r's') =>
                        move(0, 1, DIR_DOWN)
                        return movementDirty(oldX, oldY, oldTargetX, oldTargetY)
                    case KeyCode.Char(r'1') =>
                        selectTool(TOOL_HOE)
                        return selectionDirty(oldX, oldY, oldTargetX, oldTargetY)
                    case KeyCode.Char(r'2') =>
                        selectTool(TOOL_WATER)
                        return selectionDirty(oldX, oldY, oldTargetX, oldTargetY)
                    case KeyCode.Char(r'3') =>
                        selectTool(TOOL_SEED)
                        return selectionDirty(oldX, oldY, oldTargetX, oldTargetY)
                    case KeyCode.Char(r'4') =>
                        selectTool(TOOL_HARVEST)
                        return selectionDirty(oldX, oldY, oldTargetX, oldTargetY)
                    case KeyCode.Char(r'[') =>
                        selectCrop(selectedCrop - 1)
                        return selectionDirty(oldX, oldY, oldTargetX, oldTargetY)
                    case KeyCode.Char(r']') =>
                        selectCrop(selectedCrop + 1)
                        return selectionDirty(oldX, oldY, oldTargetX, oldTargetY)
                    case KeyCode.Char(r'z') | KeyCode.Char(r' ') | KeyCode.Enter =>
                        act()
                        if (day != oldDay) { return UpdateResult.dirty(fullViewRect()) }
                        return actionDirty(oldX, oldY, oldTargetX, oldTargetY)
                    case KeyCode.Char(r'p') =>
                        save()
                        return UpdateResult.dirty(panelViewRect()).withDirty(metricsViewRect())
                    case _ => return UpdateResult.dirty(metricsViewRect())
                }
            case Event.Tick(t) =>
                let oldMinute = minute
                let oldDay = day
                let oldTick = tick
                tick = t.frameIndex / ANIMATION_FRAME_DIVISOR
                advanceClock(t.deltaMillis)
                if (day != oldDay) {
                    return UpdateResult.dirty(fullViewRect())
                }
                var result = UpdateResult.dirty(metricsViewRect())
                if (minute != oldMinute) { result = result.withDirty(hudViewRect()) }
                if (tick != oldTick) {
                    for (y in 0..FARM_H) {
                        for (x in 0..FARM_W) {
                            let tile = tileAt(x, y)
                            let waterChanged = tile == "~" && oldTick % 2 != tick % 2
                            let grassChanged = tile == "." && ((x * 5 + y + oldTick / 24) % 17 == 0) != ((x * 5 + y + tick / 24) % 17 == 0)
                            if (waterChanged || grassChanged) { result = result.withDirty(farmCellViewRect(x, y)) }
                        }
                    }
                }
                return result
            case _ => ()
        }
        UpdateResult.next()
    }

    func setViewOrigin(x: Int64, y: Int64): Unit {
        viewX = x
        viewY = y
    }

    private func fullViewRect(): Rect {
        Rect(viewX, viewY, VIEW_W, VIEW_H)
    }

    private func hudViewRect(): Rect {
        Rect(viewX, viewY, VIEW_W, 4)
    }

    private func metricsViewRect(): Rect {
        Rect(viewX + 116, viewY + 49, 68, 1)
    }

    private func panelViewRect(): Rect {
        Rect(viewX + 133, viewY + 5, 48, 36)
    }

    private func hotbarViewRect(): Rect {
        Rect(viewX + 1, viewY + 43, VIEW_W - 3, 5)
    }

    private func farmCellViewRect(x: Int64, y: Int64): Rect {
        Rect(viewX + 1 + x * FARM_CELL_W, max(viewY + 4, viewY + 5 + y * FARM_CELL_H - 1), FARM_CELL_W, FARM_CELL_H + 2)
    }

    private func dirtyGameplay(oldX: Int64, oldY: Int64, oldTargetX: Int64, oldTargetY: Int64): UpdateResult {
        var result = UpdateResult.dirty(metricsViewRect())
        if (inFarmBounds(oldX, oldY)) { result = result.withDirty(farmCellViewRect(oldX, oldY)) }
        if (inFarmBounds(playerX, playerY)) { result = result.withDirty(farmCellViewRect(playerX, playerY)) }
        if (inFarmBounds(oldTargetX, oldTargetY)) { result = result.withDirty(farmCellViewRect(oldTargetX, oldTargetY)) }
        if (inFarmBounds(targetX(), targetY())) { result = result.withDirty(farmCellViewRect(targetX(), targetY())) }
        result
    }

    private func movementDirty(oldX: Int64, oldY: Int64, oldTargetX: Int64, oldTargetY: Int64): UpdateResult {
        dirtyGameplay(oldX, oldY, oldTargetX, oldTargetY).withDirty(panelViewRect())
    }

    private func selectionDirty(oldX: Int64, oldY: Int64, oldTargetX: Int64, oldTargetY: Int64): UpdateResult {
        dirtyGameplay(oldX, oldY, oldTargetX, oldTargetY).withDirty(panelViewRect()).withDirty(hotbarViewRect())
    }

    private func actionDirty(oldX: Int64, oldY: Int64, oldTargetX: Int64, oldTargetY: Int64): UpdateResult {
        dirtyGameplay(oldX, oldY, oldTargetX, oldTargetY).withDirty(hudViewRect()).withDirty(panelViewRect()).withDirty(hotbarViewRect())
    }

    private func inFarmBounds(x: Int64, y: Int64): Bool {
        x >= 0 && y >= 0 && x < FARM_W && y < FARM_H
    }

    private func buildPlots(): Unit {
        for (y in 6..15) {
            for (x in 4..24) {
                plots.add(Plot(x, y))
            }
        }
    }

    private func advanceClock(deltaMillis: Int64): Unit {
        minuteRemainderMillis += max(0, deltaMillis) * DAY_GAME_MINUTES
        let addMinutes = minuteRemainderMillis / DAY_REAL_MILLIS
        if (addMinutes > 0) {
            minute += addMinutes
            minuteRemainderMillis = minuteRemainderMillis % DAY_REAL_MILLIS
            if (minute >= DAY_END) {
                sleepNight()
            }
        }
    }

    private func move(dx: Int64, dy: Int64, dir: Int64): Unit {
        if (dir != facing) {
            facing = dir
            status = "turned " + directionName(facing)
            return
        }
        facing = dir
        let nx = playerX + dx
        let ny = playerY + dy
        if (isWalkable(nx, ny)) {
            playerX = nx
            playerY = ny
        } else {
            status = "blocked"
        }
    }

    private func selectTool(tool: Int64): Unit {
        selectedTool = clampInt(tool, TOOL_HOE, TOOL_HARVEST)
        status = "tool: " + toolName(selectedTool)
    }

    private func selectCrop(crop: Int64): Unit {
        selectedCrop = wrapCrop(crop)
        status = "seed: " + cropName(selectedCrop) + " cost " + cropCost(selectedCrop).toString()
    }

    private func act(): Unit {
        let tx = playerX + dirX(facing)
        let ty = playerY + dirY(facing)
        let tile = tileAt(tx, ty)
        if (tile == "B") {
            sleepNight()
            return
        }
        if (tile == "S") {
            buySeed(selectedCrop)
            return
        }
        if (tile == "C") {
            shipInventory()
            return
        }
        match (plotAt(tx, ty)) {
            case Some(plot) => actOnPlot(plot)
            case None => status = "nothing useful there"
        }
    }

    private func actOnPlot(plot: Plot): Unit {
        if (selectedTool == TOOL_HOE) { till(plot) }
        else if (selectedTool == TOOL_WATER) { water(plot) }
        else if (selectedTool == TOOL_SEED) { plant(plot) }
        else if (selectedTool == TOOL_HARVEST) { harvest(plot) }
    }

    private func till(plot: Plot): Unit {
        if (plot.tilled) {
            status = "soil already tilled"
            return
        }
        if (!spendEnergy(2)) { return }
        plot.tilled = true
        status = "tilled soil"
    }

    private func water(plot: Plot): Unit {
        if (!plot.tilled) {
            status = "till before watering"
            return
        }
        if (!spendEnergy(1)) { return }
        plot.watered = true
        status = "watered soil"
    }

    private func plant(plot: Plot): Unit {
        if (!plot.tilled) {
            status = "till soil before planting"
            return
        }
        if (plot.hasCrop()) {
            status = "already planted"
            return
        }
        if (seeds[selectedCrop] <= 0) {
            status = "no " + cropName(selectedCrop) + " seeds"
            return
        }
        if (!spendEnergy(1)) { return }
        seeds[selectedCrop]--
        plot.crop = selectedCrop
        plot.growth = 0
        plot.watered = false
        status = "planted " + cropName(selectedCrop)
    }

    private func harvest(plot: Plot): Unit {
        if (!plot.hasCrop()) {
            status = "nothing to harvest"
            return
        }
        if (plot.growth < cropDays(plot.crop)) {
            status = cropName(plot.crop) + " is still growing"
            return
        }
        if (inventory[plot.crop] >= MAX_SAVE_COUNT) { status = "inventory limit reached; ship crops first"; return }
        if (!spendEnergy(1)) { return }
        inventory[plot.crop]++
        status = "harvested " + cropName(plot.crop)
        plot.crop = -1
        plot.growth = 0
        plot.watered = false
        plot.tilled = true
    }

    private func buySeed(crop: Int64): Unit {
        if (seeds[crop] >= MAX_SAVE_COUNT) { status = "seed limit reached"; return }
        let cost = cropCost(crop)
        if (money < cost) {
            status = "need " + cost.toString() + "g for " + cropName(crop) + " seeds"
            return
        }
        money -= cost
        seeds[crop]++
        status = "bought " + cropName(crop) + " seed"
        save()
    }

    private func shipInventory(): Unit {
        var moved: Int64 = 0
        var cropsRemain = false
        for (i in 0..CROP_COUNT) {
            let count = min(inventory[i], MAX_SAVE_COUNT - shipping[i])
            moved += count
            shipping[i] += count
            inventory[i] -= count
            if (inventory[i] > 0) { cropsRemain = true }
        }
        if (moved == 0) {
            status = if (cropsRemain) { "shipping box full; crops remain in bag" } else { "no crops in bag to ship" }
        } else {
            status = "boxed " + moved.toString() + " crops for tonight"
            save()
        }
    }

    private func spendEnergy(cost: Int64): Bool {
        if (energy < cost) {
            status = "too tired: save or sleep"
            return false
        }
        energy -= cost
        true
    }

    private func sleepNight(): Unit {
        let shipment = shippingValue()
        if (money > MAX_SAVE_MONEY - shipment || day >= MAX_SAVE_DAY) {
            status = "save-domain limit reached; shipment retained"
            return
        }
        var earned: Int64 = 0
        for (i in 0..CROP_COUNT) {
            earned += shipping[i] * cropPrice(i)
            shipping[i] = 0
        }
        lastEarned = earned
        for (plot in plots) {
            if (plot.hasCrop() && plot.watered) {
                plot.growth = min(cropDays(plot.crop), plot.growth + 1)
            }
            plot.watered = false
        }
        money += earned
        day++
        minute = DAY_START
        minuteRemainderMillis = 0
        energy = MAX_ENERGY
        playerX = 5
        playerY = 5
        facing = DIR_DOWN
        status = if (earned > 0) { "day " + day.toString() + ": shipped for " + earned.toString() + "g" } else { "day " + day.toString() + ": rested" }
        save()
    }

    func save(): Unit {
        if (!saveAllowed) {
            status = "save disabled after load failure; original preserved (use --reset-save to replace)"
            return
        }
        try {
            ensureParent(savePath)
            File.writeTo(savePath, encodeSave().toArray())
            status = status + "  saved"
        } catch (_) {
            status = "save failed: " + savePath
        }
    }

    private func load(): Bool {
        try {
            let text = String.fromUtf8(File.readFrom(savePath))
            decodeSave(text)
            status = "loaded " + savePath
            return true
        } catch (_) {
            return false
        }
    }

    private func encodeSave(): String {
        var out = "version=1\n"
        out += "day=" + day.toString() + "\n"
        out += "minute=" + minute.toString() + "\n"
        out += "money=" + money.toString() + "\n"
        out += "energy=" + energy.toString() + "\n"
        out += "player=" + playerX.toString() + "," + playerY.toString() + "\n"
        out += "facing=" + facing.toString() + "\n"
        out += "tool=" + selectedTool.toString() + "\n"
        out += "seed=" + selectedCrop.toString() + "\n"
        out += "seeds=" + joinInts(seeds) + "\n"
        out += "inventory=" + joinInts(inventory) + "\n"
        out += "shipping=" + joinInts(shipping) + "\n"
        out += "lastEarned=" + lastEarned.toString() + "\n"
        out += "plots=" + encodePlots() + "\n"
        out
    }

    private func encodePlots(): String {
        let parts = ArrayList<String>()
        for (plot in plots) {
            if (plot.tilled || plot.hasCrop() || plot.watered) {
                let tilled = if (plot.tilled) { 1 } else { 0 }
                let watered = if (plot.watered) { 1 } else { 0 }
                parts.add(plot.x.toString() + "," + plot.y.toString() + "," + tilled.toString() + "," + plot.crop.toString() + "," + plot.growth.toString() + "," + watered.toString())
            }
        }
        joinStrings(parts.toArray(), "|")
    }

    private func decodeSave(text: String): Unit {
        for (line in splitLines(text)) {
            if (line.startsWith("day=")) { day = parseInt(line[4..], day) }
            else if (line.startsWith("minute=")) { minute = parseInt(line[7..], minute) }
            else if (line.startsWith("money=")) { money = parseInt(line[6..], money) }
            else if (line.startsWith("energy=")) { energy = parseInt(line[7..], energy) }
            else if (line.startsWith("player=")) { decodePlayer(line[7..]) }
            else if (line.startsWith("facing=")) { facing = clampInt(parseInt(line[7..], facing), DIR_UP, DIR_LEFT) }
            else if (line.startsWith("tool=")) { selectedTool = clampInt(parseInt(line[5..], selectedTool), TOOL_HOE, TOOL_HARVEST) }
            else if (line.startsWith("seed=")) { selectedCrop = wrapCrop(parseInt(line[5..], selectedCrop)) }
            else if (line.startsWith("seeds=")) { decodeCounts(line[6..], seeds) }
            else if (line.startsWith("inventory=")) { decodeCounts(line[10..], inventory) }
            else if (line.startsWith("shipping=")) { decodeCounts(line[9..], shipping) }
            else if (line.startsWith("lastEarned=")) { lastEarned = clampInt(parseInt(line[11..], lastEarned), 0, MAX_SAVE_MONEY) }
            else if (line.startsWith("plots=")) { decodePlots(line[6..]) }
        }
        minute = clampInt(minute, DAY_START, DAY_END - 1)
        day = clampInt(day, 1, MAX_SAVE_DAY)
        money = clampInt(money, 0, MAX_SAVE_MONEY)
        energy = clampInt(energy, 0, MAX_ENERGY)
        if (!isWalkable(playerX, playerY)) {
            playerX = 6
            playerY = 6
        }
    }

    private func decodePlayer(text: String): Unit {
        let parts = split(text, b',')
        if (parts.size >= 2) {
            playerX = parseInt(parts[0], playerX)
            playerY = parseInt(parts[1], playerY)
        }
    }

    private func decodeCounts(text: String, counts: Array<Int64>): Unit {
        let parts = split(text, b',')
        for (i in 0..min(parts.size, CROP_COUNT)) {
            counts[i] = clampInt(parseInt(parts[i], counts[i]), 0, MAX_SAVE_COUNT)
        }
    }

    private func decodePlots(text: String): Unit {
        for (plot in plots) {
            plot.tilled = false
            plot.crop = -1
            plot.growth = 0
            plot.watered = false
        }
        if (text.isEmpty()) { return }
        for (entry in split(text, b'|')) {
            let parts = split(entry, b',')
            if (parts.size < 6) { continue }
            let x = parseInt(parts[0], -1)
            let y = parseInt(parts[1], -1)
            match (plotAt(x, y)) {
                case Some(plot) =>
                    plot.tilled = parseInt(parts[2], 0) != 0
                    plot.crop = clampInt(parseInt(parts[3], -1), -1, CROP_COUNT - 1)
                    plot.growth = clampInt(parseInt(parts[4], 0), 0, if (plot.crop >= 0) { cropDays(plot.crop) } else { 0 })
                    plot.watered = parseInt(parts[5], 0) != 0
                case None => ()
            }
        }
    }

    private func plotAt(x: Int64, y: Int64): ?Plot {
        for (plot in plots) {
            if (plot.x == x && plot.y == y) { return Some(plot) }
        }
        None
    }

    private func isWalkable(x: Int64, y: Int64): Bool {
        let tile = tileAt(x, y)
        tile == "." || tile == "B"
    }

    func tileAt(x: Int64, y: Int64): String {
        if (x < 0 || y < 0 || y >= FARM_ROWS.size) { return "#" }
        symbolAt(FARM_ROWS[y], x)
    }

    func targetX(): Int64 { playerX + dirX(facing) }

    func targetY(): Int64 { playerY + dirY(facing) }

    func dayProgressPercent(): Int64 {
        clampInt((minute - DAY_START) * 100 / max(1, DAY_GAME_MINUTES), 0, 100)
    }

    func energyPercent(): Int64 {
        clampInt(energy * 100 / MAX_ENERGY, 0, 100)
    }

    func shippingValue(): Int64 {
        var value: Int64 = 0
        for (i in 0..CROP_COUNT) {
            value += shipping[i] * cropPrice(i)
        }
        value
    }

    func headlessSmoke(): Bool {
        // Exercise the same tick-to-dirty path as interactive rendering.
        tick = 0
        let phase = update(Event.Tick(TickEvent(frameIndex: ANIMATION_FRAME_DIVISOR)))
        match (phase.dirtyRects) {
            case Some(rects) => if (!rects.intersects(farmCellViewRect(15, 1))) { return false }
            case None => return false
        }
        if (!saveAllowed) { return false }
        playerX = 8
        playerY = 8
        facing = DIR_DOWN
        move(0, -1, DIR_UP)
        if (playerX != 8 || playerY != 8 || facing != DIR_UP) { return false }
        move(0, -1, DIR_UP)
        if (playerX != 8 || playerY != 7 || facing != DIR_UP) { return false }
        move(1, 0, DIR_RIGHT)
        if (playerX != 8 || playerY != 7 || facing != DIR_RIGHT) { return false }
        move(1, 0, DIR_RIGHT)
        if (playerX != 9 || playerY != 7 || facing != DIR_RIGHT) { return false }
        selectedCrop = CROP_TURNIP
        money = 120
        energy = MAX_ENERGY
        buySeed(CROP_TURNIP)
        match (plotAt(6, 8)) {
            case Some(plot) =>
                selectedTool = TOOL_HOE
                till(plot)
                selectedTool = TOOL_SEED
                plant(plot)
                selectedTool = TOOL_WATER
                water(plot)
                sleepNight()
                selectedTool = TOOL_WATER
                water(plot)
                sleepNight()
                selectedTool = TOOL_WATER
                water(plot)
                sleepNight()
                selectedTool = TOOL_HARVEST
                harvest(plot)
                if (inventory[CROP_TURNIP] <= 0) { return false }
                shipInventory()
                sleepNight()
                let afterMoney = money
                save()
                let reloaded = FarmGame(savePath, false)
                reloaded.money == afterMoney && reloaded.day == day && reloaded.inventory[CROP_TURNIP] == 0
            case None => false
        }
    }
}

class FarmScene <: Widget {
    let app: FarmGame

    init(app: FarmGame) {
        this.app = app
    }

    public func render(area: Rect, buffer: Buffer): Unit {
        renderFull(area, buffer)
    }

    public func renderFrame(frame: Frame, area: Rect): Unit {
        let guard = SizeGuard(VIEW_W, VIEW_H)
        let fit = guard.fit(area)
        let canvas = frame.canvas(area: fit.content)
        if (fit.tooSmall) {
            if (frame.isDirty(area)) {
                canvas.drawText(area.x, area.y, "terminal too small for Meadow Terminal Farm", Style(fg: Color.Yellow, bg: Color.Rgb(8, 14, 13)))
            }
            return
        }
        app.setViewOrigin(fit.content.x, fit.content.y)
        let farmArea = Rect(fit.content.x + 1, fit.content.y + 5, FARM_W * FARM_CELL_W, FARM_H * FARM_CELL_H)
        let hudArea = Rect(fit.content.x, fit.content.y, VIEW_W, 4)
        let farmFrameArea = Rect(farmArea.x - 1, farmArea.y - 1, farmArea.width + 2, farmArea.height + 2)
        let panelArea = Rect(farmArea.x + farmArea.width + 4, fit.content.y + 5, 48, 36)
        let hotbarArea = Rect(fit.content.x + 1, fit.content.y + 43, VIEW_W - 3, 5)
        let helpArea = Rect(fit.content.x + 1, fit.content.y + 49, 112, 1)
        let metricsArea = Rect(fit.content.x + 116, fit.content.y + 49, 68, 1)
        if (isFullFrame(frame, area)) {
            canvas.fillRect(area, Style(bg: Color.Rgb(8, 14, 13)))
        }
        if (frame.isDirty(hudArea)) { drawHud(canvas, fit.content) }
        if (frame.isDirty(farmFrameArea)) {
            if (shouldDrawFullFarm(frame, farmFrameArea)) {
                drawFarm(canvas, farmArea)
            } else {
                drawFarmDirty(frame, canvas, farmArea)
            }
        }
        if (frame.isDirty(panelArea)) { drawPanel(canvas, panelArea) }
        if (frame.isDirty(hotbarArea)) { drawHotbar(canvas, hotbarArea) }
        if (frame.isDirty(helpArea)) {
            canvas.drawText(fit.content.x + 1, fit.content.y + 49, "WASD move   Space use   1-4 tools   [] seed   p save   q quit", Style(fg: Color.Rgb(226, 235, 226), bg: Color.Rgb(20, 27, 24)))
        }
        if (frame.isDirty(metricsArea)) {
            canvas.drawText(fit.content.x + 116, fit.content.y + 49, metricsLine(app.metrics), Style(fg: Color.Rgb(110, 210, 220), bg: Color.Rgb(8, 14, 13)))
        }
    }

    private func renderFull(area: Rect, buffer: Buffer): Unit {
        let guard = SizeGuard(VIEW_W, VIEW_H)
        let fit = guard.fit(area)
        let canvas = Canvas(buffer, fit.content)
        canvas.fillRect(area, Style(bg: Color.Rgb(8, 14, 13)))
        if (fit.tooSmall) {
            canvas.drawText(area.x, area.y, "terminal too small for Meadow Terminal Farm", Style(fg: Color.Yellow, bg: Color.Rgb(8, 14, 13)))
            return
        }
        app.setViewOrigin(fit.content.x, fit.content.y)
        drawHud(canvas, fit.content)
        let farmArea = Rect(fit.content.x + 1, fit.content.y + 5, FARM_W * FARM_CELL_W, FARM_H * FARM_CELL_H)
        drawFarm(canvas, farmArea)
        drawPanel(canvas, Rect(farmArea.x + farmArea.width + 4, fit.content.y + 5, 48, 36))
        drawHotbar(canvas, Rect(fit.content.x + 1, fit.content.y + 43, VIEW_W - 3, 5))
        canvas.drawText(fit.content.x + 1, fit.content.y + 49, "WASD move   Space use   1-4 tools   [] seed   p save   q quit", Style(fg: Color.Rgb(226, 235, 226), bg: Color.Rgb(20, 27, 24)))
        canvas.drawText(fit.content.x + 116, fit.content.y + 49, metricsLine(app.metrics), Style(fg: Color.Rgb(110, 210, 220), bg: Color.Rgb(8, 14, 13)))
    }

    private func drawHud(canvas: Canvas, area: Rect): Unit {
        canvas.fillRect(Rect(area.x, area.y, VIEW_W, 4), Style(bg: Color.Rgb(68, 44, 28)))
        drawHudBlock(canvas, area.x + 1, area.y, 31, "MEADOW", "Spring ${app.day}", Color.Rgb(64, 96, 42), Color.Rgb(232, 190, 128))
        drawHudBlock(canvas, area.x + 34, area.y, 26, "TIME", clockText(app.minute), Color.Rgb(86, 50, 28), Color.Rgb(245, 206, 132))
        drawHudBlock(canvas, area.x + 62, area.y, 37, "DAYLIGHT", miniGauge(app.dayProgressPercent(), 16), Color.Rgb(132, 78, 34), Color.Rgb(232, 190, 128))
        drawHudBlock(canvas, area.x + 101, area.y, 37, "STAMINA", miniGauge(app.energyPercent(), 16), Color.Rgb(48, 116, 54), Color.Rgb(232, 190, 128))
        drawHudBlock(canvas, area.x + 140, area.y, 42, "GOLD / SHIP", "${app.money}g   ${app.shippingValue()}g box", Color.Rgb(132, 78, 34), Color.Rgb(245, 206, 132))
    }

    private func drawHudBlock(canvas: Canvas, x: Int64, y: Int64, width: Int64, title: String, value: String, fg: Color, bg: Color): Unit {
        let border = Style(fg: Color.Rgb(150, 98, 54), bg: Color.Rgb(68, 44, 28))
        let body = Style(fg: fg, bg: bg, modifier: Modifier.strong())
        let label = Style(fg: Color.Rgb(86, 50, 28), bg: bg, modifier: Modifier.strong())
        canvas.fillRect(Rect(x, y, width, 3), Style(bg: bg))
        canvas.strokeRect(Rect(x, y, width, 3), border)
        canvas.drawText(x + 1, y, " " + title + " ", label)
        canvas.drawText(x + 2, y + 1, clipText(value, width - 4), body)
    }

    private func drawFarm(canvas: Canvas, area: Rect): Unit {
        canvas.strokeRect(Rect(area.x - 1, area.y - 1, area.width + 2, area.height + 2), Style(fg: Color.Rgb(145, 104, 66), bg: Color.Rgb(8, 14, 13)))
        canvas.drawText(area.x, area.y - 1, " FARM ", Style(fg: Color.Rgb(255, 238, 174), bg: Color.Rgb(8, 14, 13), modifier: Modifier.strong()))
        for (y in 0..FARM_H) {
            for (x in 0..FARM_W) {
                drawBaseTile(canvas, area.x + x * FARM_CELL_W, area.y + y * FARM_CELL_H, app.tileAt(x, y), x, y)
            }
        }
        for (plot in app.plots) {
            drawPlot(canvas, area.x + plot.x * FARM_CELL_W, area.y + plot.y * FARM_CELL_H, plot)
        }
        drawTarget(canvas, area)
        let playerX = area.x + app.playerX * FARM_CELL_W
        let playerY = area.y + app.playerY * FARM_CELL_H
        drawPlayer(canvas, playerX, max(area.y, playerY - 1), tileBg(app.tileAt(app.playerX, app.playerY)))
    }

    private func shouldDrawFullFarm(frame: Frame, farmFrameArea: Rect): Bool {
        frame.isDirty(Rect(farmFrameArea.x, farmFrameArea.y, farmFrameArea.width, 1)) ||
            frame.isDirty(Rect(farmFrameArea.x, farmFrameArea.bottom - 1, farmFrameArea.width, 1)) ||
            frame.isDirty(Rect(farmFrameArea.x, farmFrameArea.y, 1, farmFrameArea.height)) ||
            frame.isDirty(Rect(farmFrameArea.right - 1, farmFrameArea.y, 1, farmFrameArea.height))
    }

    private func drawFarmDirty(frame: Frame, canvas: Canvas, area: Rect): Unit {
        for (y in 0..FARM_H) {
            for (x in 0..FARM_W) {
                if (frame.isDirty(farmCellRect(area, x, y))) {
                    drawBaseTile(canvas, area.x + x * FARM_CELL_W, area.y + y * FARM_CELL_H, app.tileAt(x, y), x, y)
                }
            }
        }
        for (plot in app.plots) {
            if (frame.isDirty(farmCellRect(area, plot.x, plot.y))) {
                drawPlot(canvas, area.x + plot.x * FARM_CELL_W, area.y + plot.y * FARM_CELL_H, plot)
            }
        }
        if (frame.isDirty(targetRect(area))) { drawTarget(canvas, area) }
        if (frame.isDirty(playerRect(area))) {
            let playerX = area.x + app.playerX * FARM_CELL_W
            let playerY = area.y + app.playerY * FARM_CELL_H
            drawPlayer(canvas, playerX, max(area.y, playerY - 1), tileBg(app.tileAt(app.playerX, app.playerY)))
        }
    }

    private func farmCellRect(area: Rect, x: Int64, y: Int64): Rect {
        Rect(area.x + x * FARM_CELL_W, area.y + y * FARM_CELL_H, FARM_CELL_W, FARM_CELL_H)
    }

    private func targetRect(area: Rect): Rect {
        let tx = app.targetX()
        let ty = app.targetY()
        if (tx < 0 || ty < 0 || tx >= FARM_W || ty >= FARM_H) { return Rect(area.x, area.y, 0, 0) }
        Rect(area.x + tx * FARM_CELL_W, area.y + ty * FARM_CELL_H, FARM_CELL_W, FARM_CELL_H)
    }

    private func playerRect(area: Rect): Rect {
        let playerX = area.x + app.playerX * FARM_CELL_W
        let playerY = area.y + app.playerY * FARM_CELL_H
        Rect(playerX, max(area.y, playerY - 1), FARM_CELL_W, FARM_CELL_H + 1)
    }

    private func drawPlayer(canvas: Canvas, x: Int64, y: Int64, bg: Color): Unit {
        let hair = Style(fg: Color.Rgb(82, 48, 28), bg: bg, modifier: Modifier.strong())
        let skin = Style(fg: Color.Rgb(246, 178, 116), bg: bg, modifier: Modifier.strong())
        let shirt = Style(fg: Color.Rgb(64, 139, 204), bg: bg, modifier: Modifier.strong())
        let pants = Style(fg: Color.Rgb(45, 74, 132), bg: bg, modifier: Modifier.strong())
        let boots = Style(fg: Color.Rgb(54, 38, 26), bg: bg, modifier: Modifier.strong())
        let shadow = Style(fg: Color.Rgb(18, 56, 30), bg: bg)

        canvas.drawText(x, y + 2, "____", shadow)
        canvas.drawText(x, y, playerHair(app.facing), hair)
        canvas.drawText(x + 1, y, playerFace(app.facing), skin)
        canvas.drawText(x, y + 1, playerArms(app.facing), skin)
        canvas.drawText(x + 1, y + 1, playerShirt(app.facing), shirt)
        canvas.drawText(x + 1, y + 2, playerPants(app.facing), pants)
        canvas.drawText(x, y + 2, playerBoots(app.facing), boots)
    }

    private func drawBaseTile(canvas: Canvas, x: Int64, y: Int64, tile: String, mapX: Int64, mapY: Int64): Unit {
        if (tile == "#") {
            let style = Style(fg: Color.Rgb(104, 78, 52), bg: Color.Rgb(58, 43, 31), modifier: Modifier.strong())
            canvas.drawText(x, y, "████", style)
            canvas.drawText(x, y + 1, "████", style)
        } else if (tile == "~") {
            let style = Style(fg: Color.Rgb(128, 210, 230), bg: Color.Rgb(35, 105, 145), modifier: Modifier.strong())
            canvas.drawText(x, y, if ((mapX + mapY + app.tick) % 2 == 0) { "~~~~" } else { "≈≈≈≈" }, style)
            canvas.drawText(x, y + 1, if ((mapX + mapY + app.tick) % 2 == 0) { "≈≈≈≈" } else { "~~~~" }, style)
        } else if (tile == "H") {
            let style = Style(fg: Color.Rgb(224, 154, 82), bg: Color.Rgb(108, 63, 43), modifier: Modifier.strong())
            canvas.drawText(x, y, "/██\\", style)
            canvas.drawText(x, y + 1, "▐▃▃▌", style)
        } else if (tile == "B") {
            let style = Style(fg: Color.Rgb(245, 194, 126), bg: Color.Rgb(108, 63, 43), modifier: Modifier.strong())
            canvas.drawText(x, y, "▛██▜", style)
            canvas.drawText(x, y + 1, "▙▄▄▟", style)
        } else if (tile == "S") {
            let style = Style(fg: Color.Rgb(248, 210, 92), bg: Color.Rgb(92, 100, 44), modifier: Modifier.strong())
            canvas.drawText(x, y, "▟██▙", style)
            canvas.drawText(x, y + 1, "▔▔▔▔", style)
        } else if (tile == "C") {
            let style = Style(fg: Color.Rgb(118, 218, 124), bg: Color.Rgb(86, 66, 38), modifier: Modifier.strong())
            canvas.drawText(x, y, "▐██▌", style)
            canvas.drawText(x, y + 1, "▐▄▄▌", style)
        } else {
            let grass = if ((mapX * 5 + mapY + app.tick / 24) % 17 == 0) { "  ▄ " } else { "    " }
            let lower = if ((mapX + mapY * 3) % 23 == 0) { " ▀  " } else { "    " }
            let style = Style(fg: Color.Rgb(82, 138, 58), bg: Color.Rgb(58, 136, 66))
            canvas.drawText(x, y, grass, style)
            canvas.drawText(x, y + 1, lower, style)
        }
    }

    private func drawPlot(canvas: Canvas, x: Int64, y: Int64, plot: Plot): Unit {
        if (!plot.tilled && !plot.hasCrop()) { return }
        let bg = if (plot.watered) { Color.Rgb(70, 55, 40) } else { Color.Rgb(91, 61, 35) }
        if (!plot.hasCrop()) {
            let style = Style(fg: Color.Rgb(174, 125, 73), bg: bg)
            canvas.drawText(x, y, if (plot.watered) { "____" } else { "----" }, style)
            canvas.drawText(x, y + 1, if (plot.watered) { "▄▄▄▄" } else { "____" }, style)
            return
        }
        let style = Style(fg: cropColor(plot.crop, plot.growth), bg: bg, modifier: Modifier.strong())
        canvas.drawText(x, y, cropSpriteTop(plot.crop, plot.growth), style)
        canvas.drawText(x, y + 1, cropSpriteBottom(plot.crop, plot.growth), style)
    }

    private func drawTarget(canvas: Canvas, area: Rect): Unit {
        let tx = app.targetX()
        let ty = app.targetY()
        if (tx < 0 || ty < 0 || tx >= FARM_W || ty >= FARM_H) { return }
        let x = area.x + tx * FARM_CELL_W
        let y = area.y + ty * FARM_CELL_H
        let label = if (app.selectedTool == TOOL_WATER) { "~~~~" } else if (app.selectedTool == TOOL_SEED) { " .. " } else { "▛▀▀▜" }
        let bottom = if (app.selectedTool == TOOL_WATER) { "~~~~" } else if (app.selectedTool == TOOL_SEED) { " .. " } else { "▙▄▄▟" }
        let style = Style(fg: Color.Rgb(255, 236, 114), bg: Color.Rgb(66, 86, 38), modifier: Modifier.strong())
        canvas.drawText(x, y, label, style)
        canvas.drawText(x, y + 1, bottom, style)
    }

    private func drawPanel(canvas: Canvas, area: Rect): Unit {
        canvas.fillRect(area, Style(bg: Color.Rgb(72, 48, 32)))
        canvas.strokeRect(area, Style(fg: Color.Rgb(156, 105, 58), bg: Color.Rgb(72, 48, 32)))
        let x = area.x + 1
        var y = area.y + 1
        canvas.drawText(x, y, "FARM BOARD", Style(fg: Color.Rgb(255, 224, 145), bg: Color.Rgb(72, 48, 32), modifier: Modifier.strong()))
        canvas.drawText(x + 29, y, "last ${app.lastEarned}g", Style(fg: Color.Rgb(255, 218, 96), bg: Color.Rgb(72, 48, 32)))
        y += 2

        drawSideCard(canvas, x, y, 46, "STATUS")
        canvas.drawText(x + 2, y + 1, "tool  " + toolBadge(app.selectedTool), Style(fg: Color.Rgb(66, 45, 28), bg: Color.Rgb(232, 190, 128), modifier: Modifier.strong()))
        canvas.drawText(x + 2, y + 2, "seed  " + cropName(app.selectedCrop) + "  " + cropCost(app.selectedCrop).toString() + "g > " + cropPrice(app.selectedCrop).toString() + "g", Style(fg: Color.Rgb(96, 59, 33), bg: Color.Rgb(232, 190, 128)))
        canvas.drawText(x + 2, y + 3, "goal  " + clipText(nextGoal(), 35), Style(fg: Color.Rgb(64, 96, 42), bg: Color.Rgb(232, 190, 128), modifier: Modifier.strong()))
        y += 6

        drawSideCard(canvas, x, y, 46, "SEED MARKET")
        for (i in 0..CROP_COUNT) {
            let row = y + 1 + i
            let active = i == app.selectedCrop
            let bg = if (active) { Color.Rgb(245, 206, 132) } else { Color.Rgb(232, 190, 128) }
            let mark = if (active) { ">" } else { " " }
            canvas.drawText(x + 2, row, mark + " " + cropSprite(i, cropDays(i)) + " " + cropName(i), Style(fg: cropColor(i, cropDays(i)), bg: bg, modifier: if (active) { Modifier.strong() } else { Modifier.none() }))
            canvas.drawText(x + 27, row, app.seeds[i].toString() + " owned", Style(fg: Color.Rgb(68, 45, 28), bg: bg))
            canvas.drawText(x + 38, row, cropDays(i).toString() + "d", Style(fg: Color.Rgb(105, 77, 48), bg: bg))
        }
        y += 6

        drawSideCard(canvas, x, y, 46, "BAG")
        for (i in 0..CROP_COUNT) {
            canvas.drawText(x + 2 + i * 14, y + 1, cropSprite(i, cropDays(i)), Style(fg: cropColor(i, cropDays(i)), bg: Color.Rgb(232, 190, 128), modifier: Modifier.strong()))
            canvas.drawText(x + 2 + i * 14, y + 2, "bag " + app.inventory[i].toString(), Style(fg: Color.Rgb(66, 45, 28), bg: Color.Rgb(232, 190, 128)))
            canvas.drawText(x + 2 + i * 14, y + 3, "box " + app.shipping[i].toString(), Style(fg: Color.Rgb(54, 116, 52), bg: Color.Rgb(232, 190, 128), modifier: Modifier.strong()))
        }
        y += 6

        drawSideCard(canvas, x, y, 46, "MAP")
        canvas.drawText(x + 2, y + 1, "SHOP  seed shop", Style(fg: Color.Rgb(128, 72, 32), bg: Color.Rgb(232, 190, 128), modifier: Modifier.strong()))
        canvas.drawText(x + 2, y + 2, "BOX   shipping box", Style(fg: Color.Rgb(54, 116, 52), bg: Color.Rgb(232, 190, 128), modifier: Modifier.strong()))
        canvas.drawText(x + 2, y + 3, "BED   new day", Style(fg: Color.Rgb(128, 72, 32), bg: Color.Rgb(232, 190, 128), modifier: Modifier.strong()))
        y += 6

        drawSideCard(canvas, x, y, 46, "NOTICE")
        canvas.drawText(x + 2, y + 1, clipText(app.status, 42), Style(fg: Color.Rgb(64, 96, 42), bg: Color.Rgb(232, 190, 128), modifier: Modifier.strong()))
    }

    private func drawSideCard(canvas: Canvas, x: Int64, y: Int64, width: Int64, title: String): Unit {
        canvas.fillRect(Rect(x, y, width, 5), Style(bg: Color.Rgb(232, 190, 128)))
        canvas.strokeRect(Rect(x, y, width, 5), Style(fg: Color.Rgb(128, 72, 32), bg: Color.Rgb(232, 190, 128)))
        canvas.drawText(x + 2, y, " " + title + " ", Style(fg: Color.Rgb(86, 50, 28), bg: Color.Rgb(232, 190, 128), modifier: Modifier.strong()))
    }

    private func drawHotbar(canvas: Canvas, area: Rect): Unit {
        canvas.fillRect(area, Style(bg: Color.Rgb(68, 44, 28)))
        canvas.strokeRect(area, Style(fg: Color.Rgb(150, 98, 54), bg: Color.Rgb(68, 44, 28)))
        let x = area.x + 1
        let y = area.y + 1
        canvas.drawText(x, y - 1, " TOOL BELT ", Style(fg: Color.Rgb(255, 224, 145), bg: Color.Rgb(68, 44, 28), modifier: Modifier.strong()))
        drawSlot(canvas, x, y, "1", "hoe", TOOL_HOE)
        drawSlot(canvas, x + 20, y, "2", "water", TOOL_WATER)
        drawSlot(canvas, x + 40, y, "3", cropName(app.selectedCrop), TOOL_SEED)
        drawSlot(canvas, x + 60, y, "4", "harvest", TOOL_HARVEST)
        canvas.fillRect(Rect(x + 84, y, 45, 3), Style(bg: Color.Rgb(232, 190, 128)))
        canvas.strokeRect(Rect(x + 84, y, 45, 3), Style(fg: Color.Rgb(128, 72, 32), bg: Color.Rgb(232, 190, 128)))
        canvas.drawText(x + 86, y, "NEXT", Style(fg: Color.Rgb(86, 50, 28), bg: Color.Rgb(232, 190, 128), modifier: Modifier.strong()))
        canvas.drawText(x + 86, y + 1, clipText(nextGoal(), 39), Style(fg: Color.Rgb(64, 96, 42), bg: Color.Rgb(232, 190, 128), modifier: Modifier.strong()))
        canvas.fillRect(Rect(x + 132, y, 47, 3), Style(bg: Color.Rgb(232, 190, 128)))
        canvas.strokeRect(Rect(x + 132, y, 47, 3), Style(fg: Color.Rgb(128, 72, 32), bg: Color.Rgb(232, 190, 128)))
        canvas.drawText(x + 134, y, "SPACE use target   [] seed", Style(fg: Color.Rgb(86, 50, 28), bg: Color.Rgb(232, 190, 128), modifier: Modifier.strong()))
        canvas.drawText(x + 134, y + 1, "p save   q quit", Style(fg: Color.Rgb(105, 77, 48), bg: Color.Rgb(232, 190, 128)))
    }

    private func drawSlot(canvas: Canvas, x: Int64, y: Int64, key: String, label: String, tool: Int64): Unit {
        let active = app.selectedTool == tool
        let bg = if (active) { Color.Rgb(246, 205, 128) } else { Color.Rgb(190, 132, 74) }
        let fg = if (active) { Color.Rgb(64, 38, 22) } else { Color.Rgb(86, 50, 28) }
        canvas.fillRect(Rect(x, y, 18, 3), Style(bg: bg))
        canvas.strokeRect(Rect(x, y, 18, 3), Style(fg: if (active) { Color.Rgb(255, 236, 158) } else { Color.Rgb(128, 72, 32) }, bg: bg))
        canvas.drawText(x + 1, y, "[" + key + "] " + toolIcon(tool), Style(fg: fg, bg: bg, modifier: if (active) { Modifier.strong() } else { Modifier.none() }))
        canvas.drawText(x + 1, y + 1, clipText(label, 14), Style(fg: fg, bg: bg, modifier: if (active) { Modifier.strong() } else { Modifier.none() }))
    }

    private func nextGoal(): String {
        if (app.seeds[0] + app.seeds[1] + app.seeds[2] == 0 && app.money >= cropCost(app.selectedCrop)) {
            return "buy seeds at SE"
        }
        if (app.shippingValue() > 0) {
            return "sleep to earn " + app.shippingValue().toString() + "g"
        }
        for (plot in app.plots) {
            if (plot.hasCrop() && plot.growth >= cropDays(plot.crop)) { return "harvest mature crops" }
        }
        for (plot in app.plots) {
            if (plot.hasCrop() && !plot.watered) { return "water planted rows" }
        }
        "expand the field"
    }
}

func parseOptions(args: Array<String>): Options {
    var savePath = "target/game_demo.save"
    var resetSave = false
    var headlessSmoke = false
    var i: Int64 = 0
    while (i < args.size) {
        match (args[i]) {
            case "--save-path" =>
                if (i + 1 < args.size) {
                    savePath = args[i + 1]
                    i += 2
                } else { i++ }
            case "--reset-save" =>
                resetSave = true
                i++
            case "--headless-smoke" =>
                headlessSmoke = true
                i++
            case _ => i++
        }
    }
    Options(savePath, resetSave, headlessSmoke)
}

func cropName(crop: Int64): String {
    if (crop == CROP_TURNIP) { "turnip" }
    else if (crop == CROP_POTATO) { "potato" }
    else if (crop == CROP_BERRY) { "berry" }
    else { "unknown" }
}

func cropCost(crop: Int64): Int64 {
    if (crop == CROP_TURNIP) { 20 }
    else if (crop == CROP_POTATO) { 35 }
    else if (crop == CROP_BERRY) { 50 }
    else { 0 }
}

func cropPrice(crop: Int64): Int64 {
    if (crop == CROP_TURNIP) { 45 }
    else if (crop == CROP_POTATO) { 80 }
    else if (crop == CROP_BERRY) { 130 }
    else { 0 }
}

func cropDays(crop: Int64): Int64 {
    if (crop == CROP_TURNIP) { 3 }
    else if (crop == CROP_POTATO) { 4 }
    else if (crop == CROP_BERRY) { 5 }
    else { 3 }
}

func cropSprite(crop: Int64, growth: Int64): String {
    if (growth <= 0) { return " .. " }
    if (growth < cropDays(crop) / 2) { return " ██ " }
    if (growth < cropDays(crop)) { return "████" }
    if (crop == CROP_TURNIP) { "▟██▙" }
    else if (crop == CROP_POTATO) { "▄██▄" }
    else if (crop == CROP_BERRY) { "▟██▙" }
    else { "████" }
}

func cropSpriteTop(crop: Int64, growth: Int64): String {
    if (growth <= 0) { return " .. " }
    if (growth < cropDays(crop) / 2) { return " ██ " }
    if (growth < cropDays(crop)) { return "████" }
    if (crop == CROP_TURNIP) { "▟██▙" }
    else if (crop == CROP_POTATO) { return "▄██▄" }
    else if (crop == CROP_BERRY) { return "▟██▙" }
    else { "████" }
}

func cropSpriteBottom(crop: Int64, growth: Int64): String {
    if (growth <= 0) { return "    " }
    if (growth < cropDays(crop) / 2) { return " ▌▐ " }
    if (growth < cropDays(crop)) { return " ▐▌ " }
    if (crop == CROP_TURNIP) { " ▀▀ " }
    else if (crop == CROP_POTATO) { " ▄▄ " }
    else if (crop == CROP_BERRY) { " ▀▀ " }
    else { "____" }
}

func cropColor(crop: Int64, growth: Int64): Color {
    if (growth < cropDays(crop)) { return Color.Rgb(120, 218, 95) }
    if (crop == CROP_TURNIP) { Color.Rgb(230, 236, 190) }
    else if (crop == CROP_POTATO) { Color.Rgb(210, 166, 82) }
    else if (crop == CROP_BERRY) { Color.Rgb(235, 88, 126) }
    else { Color.White }
}

func toolName(tool: Int64): String {
    if (tool == TOOL_HOE) { "hoe" }
    else if (tool == TOOL_WATER) { "watering can" }
    else if (tool == TOOL_SEED) { "seed" }
    else if (tool == TOOL_HARVEST) { "harvest" }
    else { "unknown" }
}

func toolBadge(tool: Int64): String {
    if (tool == TOOL_HOE) { "[1] hoe" }
    else if (tool == TOOL_WATER) { "[2] water" }
    else if (tool == TOOL_SEED) { "[3] seed" }
    else if (tool == TOOL_HARVEST) { "[4] harvest" }
    else { "[?] unknown" }
}

func toolIcon(tool: Int64): String {
    if (tool == TOOL_HOE) { "HOE " }
    else if (tool == TOOL_WATER) { "WATR" }
    else if (tool == TOOL_SEED) { "SEED" }
    else if (tool == TOOL_HARVEST) { "CUT " }
    else { "????" }
}

func directionName(facing: Int64): String {
    if (facing == DIR_UP) { "up" }
    else if (facing == DIR_RIGHT) { "right" }
    else if (facing == DIR_DOWN) { "down" }
    else if (facing == DIR_LEFT) { "left" }
    else { "around" }
}

func playerHair(facing: Int64): String {
    if (facing == DIR_UP) { "▄██▄" }
    else if (facing == DIR_RIGHT) { "▄██ " }
    else if (facing == DIR_DOWN) { "▄██▄" }
    else if (facing == DIR_LEFT) { " ██▄" }
    else { "▄██▄" }
}

func playerFace(facing: Int64): String {
    if (facing == DIR_UP) { "██" }
    else if (facing == DIR_RIGHT) { "• " }
    else if (facing == DIR_DOWN) { "••" }
    else if (facing == DIR_LEFT) { " •" }
    else { "••" }
}

func playerArms(facing: Int64): String {
    if (facing == DIR_RIGHT) { "  ▐ " }
    else if (facing == DIR_LEFT) { " ▌  " }
    else { "▌  ▐" }
}

func playerShirt(facing: Int64): String {
    if (facing == DIR_RIGHT) { "██" }
    else if (facing == DIR_LEFT) { "██" }
    else { "██" }
}

func playerPants(facing: Int64): String {
    if (facing == DIR_RIGHT) { "▐▌" }
    else if (facing == DIR_LEFT) { "▐▌" }
    else { "▐▌" }
}

func playerBoots(facing: Int64): String {
    if (facing == DIR_RIGHT) { "▔  ▔" }
    else if (facing == DIR_LEFT) { "▔  ▔" }
    else { "▔  ▔" }
}

func tileBg(tile: String): Color {
    if (tile == "B" || tile == "H") { Color.Rgb(82, 48, 40) }
    else { Color.Rgb(24, 86, 45) }
}

func dirX(facing: Int64): Int64 {
    if (facing == DIR_LEFT) { -1 } else if (facing == DIR_RIGHT) { 1 } else { 0 }
}

func dirY(facing: Int64): Int64 {
    if (facing == DIR_UP) { -1 } else if (facing == DIR_DOWN) { 1 } else { 0 }
}

func wrapCrop(crop: Int64): Int64 {
    if (crop < 0) { CROP_COUNT - 1 } else if (crop >= CROP_COUNT) { 0 } else { crop }
}

func clockText(minute: Int64): String {
    let h = minute / 60
    let m = minute % 60
    let mm = if (m < 10) { "0" + m.toString() } else { m.toString() }
    h.toString() + ":" + mm
}

func metricsLine(metrics: AppMetrics): String {
    match (metrics.lastFrame()) {
        case Some(frame) => "fps=${frame.fps} render=${frame.renderMillis}ms dirty=${frame.dirtyCells} writes=${frame.diffWrites} dropped=${frame.droppedTicks}"
        case None => "fps=0 render=0ms dirty=0 writes=0 dropped=0"
    }
}

func miniGauge(percent: Int64, width: Int64): String {
    let pct = clampInt(percent, 0, 100)
    let filled = pct * width / 100
    var out = ""
    for (i in 0..width) {
        out += if (i < filled) { "▓" } else { "░" }
    }
    out + " " + pct.toString() + "%"
}

func isFullFrame(frame: Frame, area: Rect): Bool {
    let rects = frame.dirtyRects()
    if (rects.size != 1) { return false }
    let rect = rects[0]
    rect.x == area.x && rect.y == area.y && rect.width == area.width && rect.height == area.height
}

func symbolAt(row: String, x: Int64): String {
    var cx: Int64 = 0
    for (r in row.runes()) {
        if (cx == x) { return r.toString() }
        cx += max(1, displayWidth(r))
    }
    ""
}

func splitLines(text: String): Array<String> {
    split(text, b'\n')
}

func split(text: String, sep: Byte): Array<String> {
    let out = ArrayList<String>()
    var start: Int64 = 0
    var i: Int64 = 0
    while (i < text.size) {
        if (text[i] == sep) {
            out.add(text[start..i])
            start = i + 1
        }
        i++
    }
    if (start <= text.size) { out.add(text[start..]) }
    out.toArray()
}

func joinInts(items: Array<Int64>): String {
    let parts = ArrayList<String>()
    for (item in items) {
        parts.add(item.toString())
    }
    joinStrings(parts.toArray(), ",")
}

func joinStrings(items: Array<String>, sep: String): String {
    var out = ""
    for (i in 0..items.size) {
        if (i > 0) { out += sep }
        out += items[i]
    }
    out
}

func parseInt(text: String, fallback: Int64): Int64 {
    try {
        Int64.parse(text)
    } catch (_) {
        fallback
    }
}

func ensureParent(path: String): Unit {
    var lastSlash: Int64 = -1
    for (i in 0..path.size) {
        if (path[i] == b'/') { lastSlash = i }
    }
    if (lastSlash > 0) {
        let parent = Path(path[..lastSlash])
        if (!exists(parent)) {
            Directory.create(parent, recursive: true)
        }
    }
}

func clampInt(value: Int64, minValue: Int64, maxValue: Int64): Int64 {
    min(max(value, minValue), maxValue)
}

func clipText(text: String, width: Int64): String {
    if (width <= 0) { return "" }
    var out = ""
    var used: Int64 = 0
    for (r in text.runes()) {
        let w = max(1, displayWidth(r))
        if (used + w > width) { return out }
        out += r.toString()
        used += w
    }
    out
}

main(args: Array<String>): Int64 {
    let opts = parseOptions(args)
    let game = FarmGame(opts.savePath, opts.resetSave)
    if (opts.headlessSmoke) {
        if (game.headlessSmoke()) {
            println("game_demo headless smoke ok")
            return 0
        }
        println("game_demo headless smoke failed")
        return 1
    }
    App(renderMode: RenderMode.Diff, targetFps: TARGET_FPS, metrics: Some(game.metrics)).runWithCommands(
        { frame => FarmScene(game).renderFrame(frame, frame.area) },
        { event => game.update(event) }
    )
    0
}
