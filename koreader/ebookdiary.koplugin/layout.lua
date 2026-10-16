local Layout = {}
function Layout.build(width, height, column_count)
    local scale = math.min(width / 600, height / 800)
    local pad = math.floor(16 * scale)
    local day_width = math.floor(32 * scale)
    local metric_width = math.floor(49 * scale)
    local top = math.floor(174 * scale)
    local bottom = height - math.floor(65 * scale)
    local row_height = math.floor((bottom - top) / 16)
    local note_width = width - 2*pad - day_width - column_count*metric_width
    return {w=width, h=height, scale=scale, pad=pad, day_width=day_width,
        metric_width=metric_width, note_width=note_width, top=top,
        row_height=row_height, bottom=top+16*row_height}
end
return Layout
