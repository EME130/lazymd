package editor

import (
	"fmt"
	"strings"

	"github.com/EME130/lazymd/internal/themes"
)

func (e *EditorModel) handleCommand(key Key) {
	switch key.Type {
	case KeyEscape:
		e.mode = ModeNormal
		e.CmdBuf = ""
	case KeyEnter:
		e.executeCommand()
		e.mode = ModeNormal
	case KeyBackspace:
		if len(e.CmdBuf) > 0 {
			e.CmdBuf = e.CmdBuf[:len(e.CmdBuf)-1]
		} else {
			e.mode = ModeNormal
		}
	case KeyChar:
		if key.Char < 128 {
			e.CmdBuf += string(key.Char)
		}
	}
}

func (e *EditorModel) executeCommand() {
	cmd := e.CmdBuf

	switch {
	case cmd == "q" || cmd == "quit":
		if e.Buf.IsDirty() {
			e.SetStatus("Unsaved changes! Use :q! to force quit or :wq to save and quit", true)
			return
		}
		e.ShouldQuit = true

	case cmd == "q!":
		e.ShouldQuit = true

	case cmd == "w" || cmd == "write":
		e.Save()

	case cmd == "wq" || cmd == "x":
		e.Save()
		e.ShouldQuit = true

	case strings.HasPrefix(cmd, "w "):
		path := strings.TrimLeft(cmd[2:], " ")
		if path != "" {
			e.SaveAs(path)
		}

	case strings.HasPrefix(cmd, "e "):
		path := strings.TrimLeft(cmd[2:], " ")
		if path != "" {
			if err := e.OpenFile(path); err != nil {
				e.SetStatus("Failed to open file", true)
			}
		}

	case cmd == "theme":
		t := themes.Current()
		e.SetStatus(fmt.Sprintf("Theme: %s (%d/%d)", t.Name, themes.CurrentIndex()+1, themes.Count()), false)

	case cmd == "theme.cycle" || cmd == "theme.next":
		themes.Cycle()
		t := themes.Current()
		e.SetStatus(fmt.Sprintf("Theme: %s", t.Name), false)

	case cmd == "theme.list":
		var names []string
		for _, t := range themes.BuiltinThemes {
			names = append(names, t.Name)
		}
		e.SetStatus("Themes: "+strings.Join(names, " "), false)

	case strings.HasPrefix(cmd, "theme "):
		name := strings.TrimLeft(cmd[6:], " ")
		if themes.SetByName(name) {
			e.SetStatus(fmt.Sprintf("Theme: %s", name), false)
		} else {
			e.SetStatus("Unknown theme. Use :theme.cycle to browse", true)
		}

	default:
		// Try plugin commands
		if e.CmdExec != nil {
			spaceIdx := strings.IndexByte(cmd, ' ')
			var cmdName, cmdArgs string
			if spaceIdx >= 0 {
				cmdName = cmd[:spaceIdx]
				cmdArgs = cmd[spaceIdx+1:]
			} else {
				cmdName = cmd
			}
			if e.CmdExec.ExecuteCommand(cmdName, e, cmdArgs) {
				return
			}
		}
		e.SetStatus("Unknown command", true)
	}
}
