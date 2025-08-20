package com.velocitytasks.service;

import com.velocitytasks.model.Task;
import com.velocitytasks.model.TaskPriority;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;
import java.util.stream.Collectors;

/**
 * Service class for managing tasks in VelocityTasks application.
 * Uses in-memory storage for simplicity and lightweight operation.
 */
public class TaskService {
    private static TaskService instance;
    private final ConcurrentMap<String, Task> tasks;

    private TaskService() {
        this.tasks = new ConcurrentHashMap<>();
        initializeSampleData();
    }

    /**
     * Get singleton instance of TaskService
     */
    public static synchronized TaskService getInstance() {
        if (instance == null) {
            instance = new TaskService();
        }
        return instance;
    }

    /**
     * Initialize with some sample data for demonstration
     */
    private void initializeSampleData() {
        addTask(new Task("Welcome to VelocityTasks! 🚀", TaskPriority.HIGH));
        addTask(new Task("Create your first real task", TaskPriority.MEDIUM));
        addTask(new Task("Explore the features", TaskPriority.LOW));
    }

    /**
     * Get all tasks sorted by creation date (newest first)
     */
    public List<Task> getAllTasks() {
        return tasks.values().stream()
                .sorted(Comparator.comparing(Task::getCreatedAt).reversed())
                .collect(Collectors.toList());
    }

    /**
     * Get a specific task by ID
     */
    public Optional<Task> getTaskById(String id) {
        return Optional.ofNullable(tasks.get(id));
    }

    /**
     * Add a new task
     */
    public Task addTask(Task task) {
        if (task == null) {
            throw new IllegalArgumentException("Task cannot be null");
        }
        if (task.getTitle() == null || task.getTitle().trim().isEmpty()) {
            throw new IllegalArgumentException("Task title cannot be empty");
        }
        
        // Ensure task has an ID
        if (task.getId() == null) {
            task = new Task(task.getTitle(), task.getPriority());
        }
        
        tasks.put(task.getId(), task);
        return task;
    }

    /**
     * Update an existing task
     */
    public Optional<Task> updateTask(String id, Task updatedTask) {
        if (id == null || updatedTask == null) {
            return Optional.empty();
        }
        
        Task existingTask = tasks.get(id);
        if (existingTask == null) {
            return Optional.empty();
        }
        
        // Update fields
        if (updatedTask.getTitle() != null && !updatedTask.getTitle().trim().isEmpty()) {
            existingTask.setTitle(updatedTask.getTitle());
        }
        if (updatedTask.getPriority() != null) {
            existingTask.setPriority(updatedTask.getPriority());
        }
        existingTask.setCompleted(updatedTask.isCompleted());
        
        return Optional.of(existingTask);
    }

    /**
     * Delete a task
     */
    public boolean deleteTask(String id) {
        return tasks.remove(id) != null;
    }

    /**
     * Get tasks by completion status
     */
    public List<Task> getTasksByStatus(boolean completed) {
        return tasks.values().stream()
                .filter(task -> task.isCompleted() == completed)
                .sorted(Comparator.comparing(Task::getCreatedAt).reversed())
                .collect(Collectors.toList());
    }

    /**
     * Get tasks by priority
     */
    public List<Task> getTasksByPriority(TaskPriority priority) {
        return tasks.values().stream()
                .filter(task -> task.getPriority() == priority)
                .sorted(Comparator.comparing(Task::getCreatedAt).reversed())
                .collect(Collectors.toList());
    }

    /**
     * Search tasks by title (case-insensitive)
     */
    public List<Task> searchTasks(String query) {
        if (query == null || query.trim().isEmpty()) {
            return getAllTasks();
        }
        
        String lowerQuery = query.toLowerCase();
        return tasks.values().stream()
                .filter(task -> task.getTitle().toLowerCase().contains(lowerQuery))
                .sorted(Comparator.comparing(Task::getCreatedAt).reversed())
                .collect(Collectors.toList());
    }

    /**
     * Get task statistics
     */
    public TaskStats getTaskStats() {
        long total = tasks.size();
        long completed = tasks.values().stream()
                .mapToLong(task -> task.isCompleted() ? 1 : 0)
                .sum();
        long pending = total - completed;
        
        long highPriority = tasks.values().stream()
                .mapToLong(task -> task.getPriority() == TaskPriority.HIGH ? 1 : 0)
                .sum();
        long mediumPriority = tasks.values().stream()
                .mapToLong(task -> task.getPriority() == TaskPriority.MEDIUM ? 1 : 0)
                .sum();
        long lowPriority = tasks.values().stream()
                .mapToLong(task -> task.getPriority() == TaskPriority.LOW ? 1 : 0)
                .sum();
        
        return new TaskStats(total, completed, pending, highPriority, mediumPriority, lowPriority);
    }

    /**
     * Inner class for task statistics
     */
    public static class TaskStats {
        private final long total;
        private final long completed;
        private final long pending;
        private final long highPriority;
        private final long mediumPriority;
        private final long lowPriority;

        public TaskStats(long total, long completed, long pending, 
                        long highPriority, long mediumPriority, long lowPriority) {
            this.total = total;
            this.completed = completed;
            this.pending = pending;
            this.highPriority = highPriority;
            this.mediumPriority = mediumPriority;
            this.lowPriority = lowPriority;
        }

        // Getters
        public long getTotal() { return total; }
        public long getCompleted() { return completed; }
        public long getPending() { return pending; }
        public long getHighPriority() { return highPriority; }
        public long getMediumPriority() { return mediumPriority; }
        public long getLowPriority() { return lowPriority; }
    }
}
