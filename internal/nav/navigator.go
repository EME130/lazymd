package nav

// SectionContent is the result of reading a section by heading path.
type SectionContent struct {
	HeadingLine int
	Level       int
	Title       string
	Content     string
	StartLine   int // first content line after heading
	EndLine     int // exclusive
}

// TaskStatus filters task listing.
type TaskStatus int

const (
	TaskAll     TaskStatus = 0
	TaskPending TaskStatus = 1
	TaskDone    TaskStatus = 2
)

// TaskItem represents a task checkbox found in the document.
type TaskItem struct {
	Line       int
	Done       bool
	Text       string
	Breadcrumb string
}

// Navigator is the interface for section-based document navigation.
type Navigator interface {
	ReadSection(headingPath string) (*SectionContent, error)
	ListTasks(section *string, status TaskStatus) ([]TaskItem, error)
	UpdateTask(line int, done bool) (string, error)
	GetBreadcrumb(line int) (string, error)
	MoveSection(heading, target string, before bool) (string, error)
	ReadSectionRange(headingPath string, startOff, endOff *int) (string, error)
}
