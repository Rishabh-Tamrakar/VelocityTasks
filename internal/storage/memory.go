package storage

import (
	"encoding/json"
	"fmt"
	"os"
	"sort"
	"sync"

	"github.com/rishabh-tamrakar/velocitytasks/internal/models"
)

// MemoryStorage provides thread-safe in-memory storage for tasks
type MemoryStorage struct {
	tasks     map[string]*models.Task
	mutex     sync.RWMutex
	maxTasks  int
	persistence *PersistenceConfig
}

// PersistenceConfig holds configuration for data persistence
type PersistenceConfig struct {
	Enabled  bool
	FilePath string
}

// TaskStorage defines the interface for task storage operations
type TaskStorage interface {
	Create(task *models.Task) error
	GetByID(id string) (*models.Task, error)
	GetAll() ([]*models.Task, error)
	Update(task *models.Task) error
	Delete(id string) error
	Search(params models.SearchParams) ([]*models.Task, error)
	GetStats() (*models.TaskStats, error)
	Count() int
}

// NewMemoryStorage creates a new in-memory storage instance
func NewMemoryStorage(maxTasks int, persistence *PersistenceConfig) *MemoryStorage {
	storage := &MemoryStorage{
		tasks:       make(map[string]*models.Task),
		maxTasks:    maxTasks,
		persistence: persistence,
	}

	// Load existing data if persistence is enabled
	if persistence != nil && persistence.Enabled {
		storage.loadFromFile()
	}

	return storage
}

// Create adds a new task to storage
func (m *MemoryStorage) Create(task *models.Task) error {
	if task == nil {
		return fmt.Errorf("task cannot be nil")
	}

	if err := task.Validate(); err != nil {
		return fmt.Errorf("invalid task: %w", err)
	}

	m.mutex.Lock()
	defer m.mutex.Unlock()

	// Check if we've reached the maximum number of tasks
	if len(m.tasks) >= m.maxTasks {
		return fmt.Errorf("maximum number of tasks (%d) reached", m.maxTasks)
	}

	// Check if task with this ID already exists
	if _, exists := m.tasks[task.ID]; exists {
		return fmt.Errorf("task with ID %s already exists", task.ID)
	}

	// Store the task
	m.tasks[task.ID] = task

	// Persist to file if enabled
	if m.persistence != nil && m.persistence.Enabled {
		go m.saveToFile() // Async save to avoid blocking
	}

	return nil
}

// GetByID retrieves a task by its ID
func (m *MemoryStorage) GetByID(id string) (*models.Task, error) {
	if id == "" {
		return nil, fmt.Errorf("task ID cannot be empty")
	}

	m.mutex.RLock()
	defer m.mutex.RUnlock()

	task, exists := m.tasks[id]
	if !exists {
		return nil, fmt.Errorf("task with ID %s not found", id)
	}

	// Return a copy to prevent external modifications
	taskCopy := *task
	return &taskCopy, nil
}

// GetAll retrieves all tasks, sorted by creation date (newest first)
func (m *MemoryStorage) GetAll() ([]*models.Task, error) {
	m.mutex.RLock()
	defer m.mutex.RUnlock()

	tasks := make([]*models.Task, 0, len(m.tasks))
	for _, task := range m.tasks {
		// Add a copy to prevent external modifications
		taskCopy := *task
		tasks = append(tasks, &taskCopy)
	}

	// Sort by creation date (newest first)
	sort.Slice(tasks, func(i, j int) bool {
		return tasks[i].CreatedAt.After(tasks[j].CreatedAt)
	})

	return tasks, nil
}

// Update modifies an existing task
func (m *MemoryStorage) Update(task *models.Task) error {
	if task == nil {
		return fmt.Errorf("task cannot be nil")
	}

	if err := task.Validate(); err != nil {
		return fmt.Errorf("invalid task: %w", err)
	}

	m.mutex.Lock()
	defer m.mutex.Unlock()

	// Check if task exists
	if _, exists := m.tasks[task.ID]; !exists {
		return fmt.Errorf("task with ID %s not found", task.ID)
	}

	// Update the task
	m.tasks[task.ID] = task

	// Persist to file if enabled
	if m.persistence != nil && m.persistence.Enabled {
		go m.saveToFile() // Async save to avoid blocking
	}

	return nil
}

// Delete removes a task from storage
func (m *MemoryStorage) Delete(id string) error {
	if id == "" {
		return fmt.Errorf("task ID cannot be empty")
	}

	m.mutex.Lock()
	defer m.mutex.Unlock()

	// Check if task exists
	if _, exists := m.tasks[id]; !exists {
		return fmt.Errorf("task with ID %s not found", id)
	}

	// Delete the task
	delete(m.tasks, id)

	// Persist to file if enabled
	if m.persistence != nil && m.persistence.Enabled {
		go m.saveToFile() // Async save to avoid blocking
	}

	return nil
}

// Search finds tasks matching the given criteria
func (m *MemoryStorage) Search(params models.SearchParams) ([]*models.Task, error) {
	m.mutex.RLock()
	defer m.mutex.RUnlock()

	var matches []*models.Task

	for _, task := range m.tasks {
		if task.MatchesSearch(params) {
			// Add a copy to prevent external modifications
			taskCopy := *task
			matches = append(matches, &taskCopy)
		}
	}

	// Sort by creation date (newest first)
	sort.Slice(matches, func(i, j int) bool {
		return matches[i].CreatedAt.After(matches[j].CreatedAt)
	})

	// Apply pagination if specified
	if params.Limit > 0 {
		start := params.Offset
		end := start + params.Limit

		if start >= len(matches) {
			return []*models.Task{}, nil
		}

		if end > len(matches) {
			end = len(matches)
		}

		matches = matches[start:end]
	}

	return matches, nil
}

// GetStats calculates and returns task statistics
func (m *MemoryStorage) GetStats() (*models.TaskStats, error) {
	m.mutex.RLock()
	defer m.mutex.RUnlock()

	stats := &models.TaskStats{}

	for _, task := range m.tasks {
		stats.Total++

		// Count by status
		switch task.Status {
		case models.StatusPending:
			stats.Pending++
		case models.StatusInProgress:
			stats.Progress++
		case models.StatusCompleted:
			stats.Completed++
		}

		// Count by priority
		switch task.Priority {
		case models.PriorityLow:
			stats.LowPriority++
		case models.PriorityMedium:
			stats.MediumPriority++
		case models.PriorityHigh:
			stats.HighPriority++
		}
	}

	return stats, nil
}

// Count returns the total number of tasks
func (m *MemoryStorage) Count() int {
	m.mutex.RLock()
	defer m.mutex.RUnlock()
	return len(m.tasks)
}

// saveToFile persists tasks to a JSON file
func (m *MemoryStorage) saveToFile() error {
	if m.persistence == nil || !m.persistence.Enabled {
		return nil
	}

	m.mutex.RLock()
	tasks := make([]*models.Task, 0, len(m.tasks))
	for _, task := range m.tasks {
		tasks = append(tasks, task)
	}
	m.mutex.RUnlock()

	data, err := json.MarshalIndent(tasks, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal tasks: %w", err)
	}

	err = os.WriteFile(m.persistence.FilePath, data, 0644)
	if err != nil {
		return fmt.Errorf("failed to write tasks to file: %w", err)
	}

	return nil
}

// loadFromFile loads tasks from a JSON file
func (m *MemoryStorage) loadFromFile() error {
	if m.persistence == nil || !m.persistence.Enabled {
		return nil
	}

	// Check if file exists
	if _, err := os.Stat(m.persistence.FilePath); os.IsNotExist(err) {
		return nil // File doesn't exist, start with empty storage
	}

	data, err := os.ReadFile(m.persistence.FilePath)
	if err != nil {
		return fmt.Errorf("failed to read tasks file: %w", err)
	}

	var tasks []*models.Task
	err = json.Unmarshal(data, &tasks)
	if err != nil {
		return fmt.Errorf("failed to unmarshal tasks: %w", err)
	}

	// Load tasks into memory
	m.mutex.Lock()
	defer m.mutex.Unlock()

	for _, task := range tasks {
		if task != nil && task.ID != "" {
			m.tasks[task.ID] = task
		}
	}

	return nil
}

// Clear removes all tasks from storage
func (m *MemoryStorage) Clear() error {
	m.mutex.Lock()
	defer m.mutex.Unlock()

	m.tasks = make(map[string]*models.Task)

	// Clear persistence file if enabled
	if m.persistence != nil && m.persistence.Enabled {
		go m.saveToFile()
	}

	return nil
}
