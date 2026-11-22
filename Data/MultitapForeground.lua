-- Compatibility with Telperion's Multitap Factory 1.1/1.2. These foregrounds
-- bundle their own renderer. Keep its timing, noteskin actors and judgments,
-- and supply the columns of the actual notes to its two consumers.
local path, source = ...
local function compile(text)
	return assert(loadstring(text, "@" .. path))
end

if not source:match("multitap_version%s*=%s*{%s*1%s*,%s*[12]%s*}") then
	return compile(source)
end
local turned, per_row = {}, {}
for _, player in ipairs(GAMESTATE:GetEnabledPlayers()) do
	local pn = tonumber(player:match("%d+$"))
	local opts = GAMESTATE:GetPlayerState(player):GetPlayerOptions("ModsLevel_Stage")
	per_row[pn] = opts:SuperShuffle() or opts:HyperShuffle()
	if per_row[pn] or opts:Mirror() or opts:LRMirror() or opts:UDMirror() or
		opts:Backwards() or opts:Left() or opts:Right() or opts:Shuffle() or opts:SoftShuffle() then
		turned[pn] = true
	end
end
if not next(turned) then return compile(source) end

-- Adapt only the known call sites, together. A newer implementation or an
-- unrecognized customization should run exactly as the author supplied it.
local edits = {
	{"calc_zoom_splines(multitaps[multitap_chart_sel[pn]], pn)",
	 "calc_zoom_splines(turn_masks(multitaps[multitap_chart_sel[pn]], pn, pp), pn)"},
	{"local lperm = lane_permute(pops, mt_desc.lane)",
	 "local lperm = turn_lane(pn, mt_desc, mt_stats, pops, lane_permute)"},
	{"if mt_stats.vis then", "if mt_stats.vis and lperm then"},
	{"local lperm = lane_permute(pops, lane)", "local lperm = lane"},
}
local adapted = source
for _, edit in ipairs(edits) do
	local first, last = adapted:find(edit[1], 1, true)
	if not first or adapted:find(edit[1], last + 1, true) then return compile(source) end
	adapted = adapted:sub(1, first - 1) .. edit[2] .. adapted:sub(last + 1)
end

local lanes = {}
local function turn_masks(groups, pn, player)
	if not groups or not turned[pn] then return groups end
	local field = player:GetChild("NoteField")
	local masks = {}
	lanes[pn] = {}
	-- Older factories size their splines from the descriptors alone.
	for column in ipairs(field:GetColumnActors()) do
		masks[column] = {lane = column, taps = {}}
	end
	for _, group in ipairs(groups) do
		local columns = {}
		lanes[pn][group] = columns
		local mask
		for i, beat in ipairs(group.taps) do
			local column = field:GetColumnForChartTap(group.lane, beat)
			columns[i] = column
			if column then
				-- A fixed turn moves the whole masked interval. A per-row
				-- shuffle must leave unrelated notes between hits visible.
				if per_row[pn] or not mask or column ~= mask.lane then
					mask = {lane = column, taps = {}}
					masks[#masks + 1] = mask
				end
				mask.taps[#mask.taps + 1] = beat
			end
		end
	end
	return masks
end

local function turn_lane(pn, group, phase, opts, original)
	if not turned[pn] then return original(opts, group.lane) end
	local columns = lanes[pn][group]
	return columns and columns[#group.taps - phase.rem + 1]
end

-- Keep the original chunk name so relative fonts and textures resolve in
-- the song directory. Scope the helpers to this instance of the foreground.
local chunk = compile("local turn_masks, turn_lane = ...; " .. adapted)
return function() return chunk(turn_masks, turn_lane) end
