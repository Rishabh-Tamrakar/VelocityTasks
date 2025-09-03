package handlers

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/rishabh-tamrakar/velocitytasks/internal/models"
	"github.com/rishabh-tamrakar/velocitytasks/internal/storage"
)

// TaskHandler handles HTTP requests for task operations
type TaskHandler struct {
	storage storage.TaskStorage
	logger  *log.Logger
}

// NewTaskHandler creates a new task handler
func NewTaskHandler(storage storage.TaskStorage) *TaskHandler {
	return &TaskHandler{
		storage: storage,
		logger:  log.New(log.Writer(), "[TaskHandler] ", log.LstdFlags),
	}
}

// HandleTasks handles requests to /api/tasks
func (h *TaskHandler) HandleTasks(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		h.handleGetTasks(w, r)
	case http.MethodPost:
		h.handleCreateTask(w, r)
	default:
		h.respondError(w, http.StatusMethodNotAllowed, "Method not allowed")
	}
}

// HandleTask handles requests to /api/tasks/{id}
func (h *TaskHandler) HandleTask(w http.ResponseWriter, r *http.Request) {
	// Extract task ID from URL
	parts := strings.Split(strings.Trim(r.URL.Path, "/"), "/")
	if len(parts) < 3 {
		h.respondError(w, http.StatusBadRequest, "Invalid task ID")
		return
	}
	
	taskID := parts[2]
	if taskID == "" {
		h.respondError(w, http.StatusBadRequest, "Task ID is required")
		return
	}

	switch r.Method {
	case http.MethodGet:
		h.handleGetTask(w, r, taskID)
	case http.MethodPut:
		h.handleUpdateTask(w, r, taskID)
	case http.MethodDelete:
		h.handleDeleteTask(w, r, taskID)
	default:
		h.respondError(w, http.StatusMethodNotAllowed, "Method not allowed")
	}
}

// HandleSearchTasks handles requests to /api/tasks/search
func (h *TaskHandler) HandleSearchTasks(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		h.respondError(w, http.StatusMethodNotAllowed, "Method not allowed")
		return
	}

	h.handleSearchTasks(w, r)
}

// HandleStats handles requests to /api/stats
func (h *TaskHandler) HandleStats(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		h.respondError(w, http.StatusMethodNotAllowed, "Method not allowed")
		return
	}

	h.handleGetStats(w, r)
}

// HandleHealth handles requests to /health
func (h *TaskHandler) HandleHealth(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		h.respondError(w, http.StatusMethodNotAllowed, "Method not allowed")
		return
	}

	health := map[string]interface{}{
		"status":     "healthy",
		"service":    "VelocityTasks",
		"version":    "1.0.0",
		"timestamp":  time.Now().UTC().Format(time.RFC3339),
		"task_count": h.storage.Count(),
	}

	h.respondJSON(w, http.StatusOK, health)
}

// handleGetTasks retrieves all tasks
func (h *TaskHandler) handleGetTasks(w http.ResponseWriter, r *http.Request) {
	tasks, err := h.storage.GetAll()
	if err != nil {
		h.logger.Printf("Error retrieving tasks: %v", err)
		h.respondError(w, http.StatusInternalServerError, "Failed to retrieve tasks")
		return
	}

	h.respondJSON(w, http.StatusOK, map[string]interface{}{
		"tasks": tasks,
		"total": len(tasks),
	})
}

// handleCreateTask creates a new task
func (h *TaskHandler) handleCreateTask(w http.ResponseWriter, r *http.Request) {
	var req models.CreateTaskRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.respondError(w, http.StatusBadRequest, "Invalid JSON payload")
		return
	}

	if err := req.Validate(); err != nil {
		h.respondError(w, http.StatusBadRequest, err.Error())
		return
	}

	task := models.NewTask(req.Title, req.Description, req.Priority)
	
	if err := h.storage.Create(task); err != nil {
		h.logger.Printf("Error creating task: %v", err)
		if strings.Contains(err.Error(), "maximum number") {
			h.respondError(w, http.StatusConflict, err.Error())
		} else {
			h.respondError(w, http.StatusInternalServerError, "Failed to create task")
		}
		return
	}

	h.logger.Printf("Created task: %s", task.ID)
	h.respondJSON(w, http.StatusCreated, task)
}

// handleGetTask retrieves a specific task
func (h *TaskHandler) handleGetTask(w http.ResponseWriter, r *http.Request, taskID string) {
	task, err := h.storage.GetByID(taskID)
	if err != nil {
		if strings.Contains(err.Error(), "not found") {
			h.respondError(w, http.StatusNotFound, "Task not found")
		} else {
			h.logger.Printf("Error retrieving task %s: %v", taskID, err)
			h.respondError(w, http.StatusInternalServerError, "Failed to retrieve task")
		}
		return
	}

	h.respondJSON(w, http.StatusOK, task)
}

// handleUpdateTask updates an existing task
func (h *TaskHandler) handleUpdateTask(w http.ResponseWriter, r *http.Request, taskID string) {
	// First, get the existing task
	task, err := h.storage.GetByID(taskID)
	if err != nil {
		if strings.Contains(err.Error(), "not found") {
			h.respondError(w, http.StatusNotFound, "Task not found")
		} else {
			h.logger.Printf("Error retrieving task %s: %v", taskID, err)
			h.respondError(w, http.StatusInternalServerError, "Failed to retrieve task")
		}
		return
	}

	var req models.UpdateTaskRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.respondError(w, http.StatusBadRequest, "Invalid JSON payload")
		return
	}

	if err := req.Validate(); err != nil {
		h.respondError(w, http.StatusBadRequest, err.Error())
		return
	}

	// Update the task
	task.Update(req)

	if err := h.storage.Update(task); err != nil {
		h.logger.Printf("Error updating task %s: %v", taskID, err)
		h.respondError(w, http.StatusInternalServerError, "Failed to update task")
		return
	}

	h.logger.Printf("Updated task: %s", task.ID)
	h.respondJSON(w, http.StatusOK, task)
}

// handleDeleteTask deletes a specific task
func (h *TaskHandler) handleDeleteTask(w http.ResponseWriter, r *http.Request, taskID string) {
	if err := h.storage.Delete(taskID); err != nil {
		if strings.Contains(err.Error(), "not found") {
			h.respondError(w, http.StatusNotFound, "Task not found")
		} else {
			h.logger.Printf("Error deleting task %s: %v", taskID, err)
			h.respondError(w, http.StatusInternalServerError, "Failed to delete task")
		}
		return
	}

	h.logger.Printf("Deleted task: %s", taskID)
	h.respondJSON(w, http.StatusOK, map[string]string{
		"message": "Task deleted successfully",
		"id":      taskID,
	})
}

// handleSearchTasks searches for tasks based on query parameters
func (h *TaskHandler) handleSearchTasks(w http.ResponseWriter, r *http.Request) {
	params := models.SearchParams{
		Query:    r.URL.Query().Get("q"),
		Priority: models.TaskPriority(r.URL.Query().Get("priority")),
		Status:   models.TaskStatus(r.URL.Query().Get("status")),
	}

	// Parse limit parameter
	if limitStr := r.URL.Query().Get("limit"); limitStr != "" {
		if limit, err := strconv.Atoi(limitStr); err == nil && limit > 0 {
			if limit > 1000 { // Prevent excessive resource usage
				limit = 1000
			}
			params.Limit = limit
		}
	}

	// Parse offset parameter
	if offsetStr := r.URL.Query().Get("offset"); offsetStr != "" {
		if offset, err := strconv.Atoi(offsetStr); err == nil && offset >= 0 {
			params.Offset = offset
		}
	}

	tasks, err := h.storage.Search(params)
	if err != nil {
		h.logger.Printf("Error searching tasks: %v", err)
		h.respondError(w, http.StatusInternalServerError, "Failed to search tasks")
		return
	}

	h.respondJSON(w, http.StatusOK, map[string]interface{}{
		"tasks":  tasks,
		"total":  len(tasks),
		"params": params,
	})
}

// handleGetStats retrieves task statistics
func (h *TaskHandler) handleGetStats(w http.ResponseWriter, r *http.Request) {
	stats, err := h.storage.GetStats()
	if err != nil {
		h.logger.Printf("Error retrieving stats: %v", err)
		h.respondError(w, http.StatusInternalServerError, "Failed to retrieve statistics")
		return
	}

	response := map[string]interface{}{
		"stats":     stats,
		"timestamp": time.Now().UTC().Format(time.RFC3339),
	}

	h.respondJSON(w, http.StatusOK, response)
}

// respondJSON sends a JSON response
func (h *TaskHandler) respondJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)

	if err := json.NewEncoder(w).Encode(data); err != nil {
		h.logger.Printf("Error encoding JSON response: %v", err)
	}
}

// respondError sends an error response
func (h *TaskHandler) respondError(w http.ResponseWriter, status int, message string) {
	errorResponse := map[string]interface{}{
		"error":     message,
		"status":    status,
		"timestamp": time.Now().UTC().Format(time.RFC3339),
	}

	h.respondJSON(w, status, errorResponse)
}

// EnableCORS adds CORS headers to the response
func (h *TaskHandler) EnableCORS(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")

	if r.Method == "OPTIONS" {
		w.WriteHeader(http.StatusOK)
		return
	}
}

// LogRequest logs the HTTP request
func (h *TaskHandler) LogRequest(r *http.Request) {
	h.logger.Printf("%s %s from %s", r.Method, r.URL.Path, r.RemoteAddr)
}
