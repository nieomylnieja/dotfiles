package internal

import (
	"charm.land/huh/v2"
	huhspinner "charm.land/huh/v2/spinner"
	"charm.land/lipgloss/v2"
)

// themeNord returns a huh theme based on the Nord color palette.
func themeNord() huh.Theme {
	return huh.ThemeFunc(func(isDark bool) *huh.Styles {
		t := huh.ThemeBase(isDark)

		var (
			border     = lipgloss.Color("#4C566A") // nord3
			foreground = lipgloss.Color("#D8DEE9") // nord4
			muted      = lipgloss.Color("#4C566A") // nord3
			frost      = lipgloss.Color("#88C0D0") // nord8
			blue       = lipgloss.Color("#81A1C1") // nord9
			green      = lipgloss.Color("#A3BE8C") // nord14
			red        = lipgloss.Color("#BF616A") // nord11
			yellow     = lipgloss.Color("#EBCB8B") // nord13
		)

		t.Focused.Base = t.Focused.Base.BorderForeground(border)
		t.Focused.Card = t.Focused.Base
		t.Focused.Title = t.Focused.Title.Foreground(frost).Bold(true)
		t.Focused.NoteTitle = t.Focused.NoteTitle.Foreground(frost).Bold(true)
		t.Focused.Description = t.Focused.Description.Foreground(muted)
		t.Focused.ErrorIndicator = t.Focused.ErrorIndicator.Foreground(red)
		t.Focused.ErrorMessage = t.Focused.ErrorMessage.Foreground(red)
		t.Focused.SelectSelector = t.Focused.SelectSelector.Foreground(frost)
		t.Focused.NextIndicator = t.Focused.NextIndicator.Foreground(frost)
		t.Focused.PrevIndicator = t.Focused.PrevIndicator.Foreground(frost)
		t.Focused.Option = t.Focused.Option.Foreground(foreground)
		t.Focused.MultiSelectSelector = t.Focused.MultiSelectSelector.Foreground(frost)
		t.Focused.SelectedOption = t.Focused.SelectedOption.Foreground(green)
		t.Focused.SelectedPrefix = t.Focused.SelectedPrefix.Foreground(green).SetString("[x] ")
		t.Focused.UnselectedOption = t.Focused.UnselectedOption.Foreground(foreground)
		t.Focused.UnselectedPrefix = t.Focused.UnselectedPrefix.Foreground(muted).SetString("[ ] ")
		t.Focused.FocusedButton = t.Focused.FocusedButton.Foreground(yellow).Background(blue).Bold(true)
		t.Focused.BlurredButton = t.Focused.BlurredButton.Foreground(foreground).Background(border)

		t.Focused.TextInput.Cursor = t.Focused.TextInput.Cursor.Foreground(frost)
		t.Focused.TextInput.Placeholder = t.Focused.TextInput.Placeholder.Foreground(muted)
		t.Focused.TextInput.Prompt = t.Focused.TextInput.Prompt.Foreground(frost)

		t.Blurred = t.Focused
		t.Blurred.Base = t.Blurred.Base.BorderStyle(lipgloss.HiddenBorder())
		t.Blurred.Card = t.Blurred.Base
		t.Blurred.NextIndicator = lipgloss.NewStyle()
		t.Blurred.PrevIndicator = lipgloss.NewStyle()

		t.Group.Title = t.Focused.Title
		t.Group.Description = t.Focused.Description

		return t
	})
}

func spinnerThemeNord() huhspinner.Theme {
	return huhspinner.ThemeFunc(func(bool) *huhspinner.Styles {
		return &huhspinner.Styles{
			Spinner: lipgloss.NewStyle().Foreground(lipgloss.Color("#88C0D0")),
			Title:   lipgloss.NewStyle().Foreground(lipgloss.Color("#D8DEE9")),
		}
	})
}
