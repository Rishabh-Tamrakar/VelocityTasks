package models

import (
	"errors"
	"strings"
	"time"

	"github.com/google/uuid"
)

// TaskPriority represents the priority level of a task
type TaskPriority string

const (
	PriorityLow    TaskPriority = "low"
	PriorityMedium TaskPriority = "medium"
	PriorityHigh   TaskPriority = "high"
)

// TaskStatus represents the current status of a task
type TaskStatus string

const (
	StatusPending    TaskStatus = "pending"
	StatusInProgress TaskStatus = "in_progress"
	StatusCompleted  TaskStatus = "completed"
)

// Task represents a single task in the system
type Task struct {
	ID          string       `json:"id"`
	Title       string       `json:"title"`
	Description string       `json:"description"`
	Priority    TaskPriority `json:"priority"`
	Status      TaskStatus   `json:"status"`
	CreatedAt   time.Time    `json:"created_at"`
	UpdatedAt   time.Time    `json:"updated_at"`
	CompletedAt *time.Time   `json:"completed_at,omitempty"`
}

// CreateTaskRequest represents the request payload for creating a new task
type CreateTaskRequest struct {
	Title       string       `json:"title"`
	Description string       `json:"description"`
	Priority    TaskPriority `json:"priority"`
}

// UpdateTaskRequest represents the request payload for updating a task
type UpdateTaskRequest struct {
	Title       *string       `json:"title,omitempty"`
	Description *string       `json:"description,omitempty"`
	Priority    *TaskPriority `json:"priority,omitempty"`
	Status      *TaskStatus   `json:"status,omitempty"`
}

// TaskStats represents statistics about tasks
type TaskStats struct {
	Total     int `json:"total"`
	Pending   int `json:"pending"`
	Progress  int `json:"in_progress"`
	Completed int `json:"completed"`
	HighPriority int `json:"high_priority"`
	MediumPriority int `json:"medium_priority"`
	LowPriority int `json:"low_priority"`
}

// SearchParams represents search and filter parameters
type SearchParams struct {
	Query    string       `json:"query,omitempty"`
	Priority TaskPriority `json:"priority,omitempty"`
	Status   TaskStatus   `json:"status,omitempty"`
	Limit    int          `json:"limit,omitempty"`
	Offset   int          `json:"offset,omitempty"`
}

// NewTask creates a new task with the given parameters
func NewTask(title, description string, priority TaskPriority) *Task {
	now := time.Now()
	return &Task{
		ID:          uuid.New().String(),
		Title:       strings.TrimSpace(title),
		Description: strings.TrimSpace(description),
		Priority:    priority,
		Status:      StatusPending,
		CreatedAt:   now,
		UpdatedAt:   now,
	}
}

// Validate validates the task fields
func (t *Task) Validate() error {
	if strings.TrimSpace(t.Title) == "" {
		return errors.New("title is required")
	}

	if len(t.Title) > 200 {
		return errors.New("title must be less than 200 characters")
	}

	if len(t.Description) > 1000 {
		return errors.New("description must be less than 1000 characters")
	}

	if !t.Priority.IsValid() {
		return errors.New("invalid priority value")
	}

	if !t.Status.IsValid() {
		return errors.New("invalid status value")
	}

	return nil
}

// Update updates the task with new values from the request
func (t *Task) Update(req UpdateTaskRequest) {
	now := time.Now()

	if req.Title != nil {
		t.Title = strings.TrimSpace(*req.Title)
	}

	if req.Description != nil {
		t.Description = strings.TrimSpace(*req.Description)
	}

	if req.Priority != nil {
		t.Priority = *req.Priority
	}

	if req.Status != nil {
		// Handle status transition
		oldStatus := t.Status
		t.Status = *req.Status

		// Set completion time if transitioning to completed
		if oldStatus != StatusCompleted && t.Status == StatusCompleted {
			t.CompletedAt = &now
		}

		// Clear completion time if moving away from completed
		if oldStatus == StatusCompleted && t.Status != StatusCompleted {
			t.CompletedAt = nil
		}
	}

	t.UpdatedAt = now
}

// MatchesSearch checks if the task matches the search criteria
func (t *Task) MatchesSearch(params SearchParams) bool {
	// Check query match (title or description)
	if params.Query != "" {
		query := strings.ToLower(params.Query)
		title := strings.ToLower(t.Title)
		description := strings.ToLower(t.Description)
		
		if !strings.Contains(title, query) && !strings.Contains(description, query) {
			return false
		}
	}

	// Check priority filter
	if params.Priority != "" && t.Priority != params.Priority {
		return false
	}

	// Check status filter
	if params.Status != "" && t.Status != params.Status {
		return false
	}

	return true
}

// IsValid checks if the priority value is valid
func (p TaskPriority) IsValid() bool {
	switch p {
	case PriorityLow, PriorityMedium, PriorityHigh:
		return true
	default:
		return false
	}
}

// IsValid checks if the status value is valid
func (s TaskStatus) IsValid() bool {
	switch s {
	case StatusPending, StatusInProgress, StatusCompleted:
		return true
	default:
		return false
	}
}

// Validate validates the create task request
func (r CreateTaskRequest) Validate() error {
	if strings.TrimSpace(r.Title) == "" {
		return errors.New("title is required")
	}

	if len(r.Title) > 200 {
		return errors.New("title must be less than 200 characters")
	}

	if len(r.Description) > 1000 {
		return errors.New("description must be less than 1000 characters")
	}

	if !r.Priority.IsValid() {
		return errors.New("invalid priority value")
	}

	return nil
}

// Validate validates the update task request
func (r UpdateTaskRequest) Validate() error {
	if r.Title != nil {
		if strings.TrimSpace(*r.Title) == "" {
			return errors.New("title cannot be empty")
		}
		if len(*r.Title) > 200 {
			return errors.New("title must be less than 200 characters")
		}
	}

	if r.Description != nil && len(*r.Description) > 1000 {
		return errors.New("description must be less than 1000 characters")
	}

	if r.Priority != nil && !r.Priority.IsValid() {
		return errors.New("invalid priority value")
	}

	if r.Status != nil && !r.Status.IsValid() {
		return errors.New("invalid status value")
	}

	return nil
}
