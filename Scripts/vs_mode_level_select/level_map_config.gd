class_name FW_LevelMapConfig
extends Resource

# UI Layout Constants
const H_SPACER: int = 50
const V_SPACER: int = 30

# Viewport Configuration
const VIEWPORT_SIZE: int = 6
const VIEWPORT_BUFFER: int = 1

# Line Drawing Limits
const MAX_STRUCTURE_CONNECTIONS: int = 100
const MAX_CHOICE_LINES: int = 10

# Animation Timings
const DEFAULT_SCROLL_DURATION: float = 0.5
const SCROLL_RESTORE_DURATION: float = 0.3

# Line Styling
const STRUCTURE_LINE_WIDTH: int = 20
const CHOICE_LINE_WIDTH: int = 25
const PATH_LINE_WIDTH: int = 20

# Colors
const STRUCTURE_LINE_COLOR: Color = Color(0.4, 0.4, 0.6, 0.7)
const PATH_LINE_COLOR: Color = Color(0.9, 0.9, 0.2, 0.75)
const DIMMED_NODE_COLOR: Color = Color(0.5, 0.5, 0.5, 1.0)
