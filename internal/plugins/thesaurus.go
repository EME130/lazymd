package plugins

import (
	"strings"

	"github.com/EME130/lazymd/internal/editor"
)

type ThesaurusPlugin struct{}

var synonymMap = map[string][]string{
	"good":  {"great", "excellent", "fine", "wonderful"},
	"bad":   {"poor", "terrible", "awful", "horrible"},
	"big":   {"large", "huge", "enormous", "massive"},
	"small": {"tiny", "little", "miniature", "compact"},
	"fast":  {"quick", "rapid", "swift", "speedy"},
	"slow":  {"sluggish", "gradual", "leisurely", "delayed"},
	"happy": {"joyful", "pleased", "delighted", "cheerful"},
	"sad":   {"unhappy", "sorrowful", "dejected", "melancholy"},
	"easy":  {"simple", "straightforward", "effortless", "basic"},
	"hard":  {"difficult", "challenging", "tough", "complex"},
}

func (p *ThesaurusPlugin) Info() PluginInfo {
	return PluginInfo{
		Name:        "thesaurus",
		Version:     "0.1.0",
		Author:      "LazyMD contributors",
		Description: "Synonym and antonym lookup",
	}
}

func (p *ThesaurusPlugin) Init(ed editor.PluginEditor) {}

func (p *ThesaurusPlugin) OnEvent(event *PluginEvent) {}

func (p *ThesaurusPlugin) Commands() []CommandDef {
	return []CommandDef{
		{Name: "synonyms", Description: "Find synonyms", Handler: synonymsHandler},
		{Name: "synonyms.replace", Description: "Replace with synonym", Handler: synonymsReplaceHandler},
	}
}

func synonymsHandler(ed editor.PluginEditor, args string) {
	if args == "" {
		ed.SetStatus("Usage: :synonyms <word>", false)
		return
	}

	word := strings.ToLower(args)
	synonyms, exists := synonymMap[word]

	if !exists {
		ed.SetStatus("No synonyms found for '"+args+"'", false)
		return
	}

	msg := "Synonyms for '" + args + "': " + strings.Join(synonyms, ", ")
	ed.SetStatus(msg, false)
}

func synonymsReplaceHandler(ed editor.PluginEditor, args string) {
	ed.SetStatus("Replace with synonym...", false)
}
